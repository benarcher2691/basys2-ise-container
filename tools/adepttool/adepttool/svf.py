"""Minimal SVF player on top of a Digilent DJTG port.

Local addition to the vendored adepttool (see UPSTREAM.md). Covers what
iMPACT writes for the Basys-2 chain: TRST, STATE, ENDIR, ENDDR, FREQUENCY,
HIR/TIR/HDR/TDR, SIR/SDR (TDI, TDO, MASK, SMASK) and RUNTEST.
"""

import collections
import re
import time

# TAP state graph: state -> (next state with TMS=0, next state with TMS=1).
TAP = {
    'RESET': ('IDLE', 'RESET'),
    'IDLE': ('IDLE', 'DRSELECT'),
    'DRSELECT': ('DRCAPTURE', 'IRSELECT'),
    'DRCAPTURE': ('DRSHIFT', 'DREXIT1'),
    'DRSHIFT': ('DRSHIFT', 'DREXIT1'),
    'DREXIT1': ('DRPAUSE', 'DRUPDATE'),
    'DRPAUSE': ('DRPAUSE', 'DREXIT2'),
    'DREXIT2': ('DRSHIFT', 'DRUPDATE'),
    'DRUPDATE': ('IDLE', 'DRSELECT'),
    'IRSELECT': ('IRCAPTURE', 'RESET'),
    'IRCAPTURE': ('IRSHIFT', 'IREXIT1'),
    'IRSHIFT': ('IRSHIFT', 'IREXIT1'),
    'IREXIT1': ('IRPAUSE', 'IRUPDATE'),
    'IRPAUSE': ('IRPAUSE', 'IREXIT2'),
    'IREXIT2': ('IRSHIFT', 'IRUPDATE'),
    'IRUPDATE': ('IDLE', 'DRSELECT'),
}


class SvfError(Exception):
    pass


def _tms_path(src, dst):
    """Shortest TMS sequence from src to dst (breadth-first search)."""
    if src == dst:
        return []
    seen = {src: []}
    queue = collections.deque([src])
    while queue:
        s = queue.popleft()
        for tms, nxt in enumerate(TAP[s]):
            if nxt not in seen:
                seen[nxt] = seen[s] + [tms]
                if nxt == dst:
                    return seen[nxt]
                queue.append(nxt)
    raise SvfError('no path from {} to {}'.format(src, dst))


def _pack(value, bits):
    return value.to_bytes((bits + 7) // 8, 'little')


class _Pattern:
    """Sticky TDI/MASK/SMASK values of one SVF shift type (SIR, SDR, HIR, ...)."""

    def __init__(self):
        self.length = 0
        self.tdi = 0
        self.mask = 0


class Player:
    def __init__(self, port, log=None):
        self.port = port
        self.log = log or (lambda msg: None)
        self.state = 'RESET'
        self.endir = 'IDLE'
        self.enddr = 'IDLE'
        self.freq = None          # Hz requested by the SVF
        self.actual_freq = None   # Hz the cable actually runs at
        self.pat = {k: _Pattern() for k in ('SIR', 'SDR', 'HIR', 'TIR', 'HDR', 'TDR')}
        self.checks = 0

    # --- low level -------------------------------------------------------

    def _tms(self, seq):
        if not seq:
            return
        data = sum(b << i for i, b in enumerate(seq))
        self.port.put_tms_bits(False, False, len(seq), _pack(data, len(seq)))

    def goto(self, dst):
        if dst == 'RESET':
            self._tms([1] * 5)
        else:
            self._tms(_tms_path(self.state, dst))
        self.state = dst

    def _shift(self, shift_state, value, bits, capture):
        """Shift `bits` bits LSB first; leave the shift state on the last bit."""
        self.goto(shift_state)
        tdo = 0
        if bits > 1:
            res = self.port.put_tdi_bits(capture, False, bits - 1, _pack(value & ((1 << (bits - 1)) - 1), bits - 1))
            if capture:
                tdo = int.from_bytes(res, 'little')
        last = self.port.put_tdi_bits(capture, True, 1, bytes([value >> (bits - 1) & 1]))
        if capture:
            tdo |= (last[0] & 1) << (bits - 1)
        self.state = TAP[shift_state][1]   # EXIT1
        return tdo

    def _wait_tck(self, count):
        if count <= 0:
            return
        self.port.clock_tck(False, False, count)
        # The cable may not go as slow as the SVF asks: make up the time.
        if self.freq and self.actual_freq and self.actual_freq > self.freq:
            time.sleep(count / self.freq - count / self.actual_freq)

    # --- commands --------------------------------------------------------

    def _scan(self, kind, args, lineno):
        ir = kind == 'SIR'
        pat = self.pat[kind]
        length = int(args[0])
        fields = dict(zip(args[1::2], args[2::2]))
        for key in fields:
            if key not in ('TDI', 'TDO', 'MASK', 'SMASK'):
                raise SvfError('line {}: unsupported {} field {}'.format(lineno, kind, key))
        if length != pat.length:
            pat.length = length
            pat.mask = (1 << length) - 1
            if length and 'TDI' not in fields:
                raise SvfError('line {}: {} length changed without TDI'.format(lineno, kind))
        if 'TDI' in fields:
            pat.tdi = int(fields['TDI'], 16)
        if 'MASK' in fields:
            pat.mask = int(fields['MASK'], 16)
        if kind not in ('SIR', 'SDR'):
            return
        # Full scan: trailer (TDI side) | data | header (TDO side), header first.
        hdr, trl = (self.pat['HIR'], self.pat['TIR']) if ir else (self.pat['HDR'], self.pat['TDR'])
        total = hdr.length + length + trl.length
        if total == 0:
            return
        value = hdr.tdi | pat.tdi << hdr.length | trl.tdi << (hdr.length + length)
        capture = 'TDO' in fields
        tdo = self._shift('IRSHIFT' if ir else 'DRSHIFT', value, total, capture)
        self.goto(self.endir if ir else self.enddr)
        if capture:
            got = (tdo >> hdr.length) & ((1 << length) - 1)
            want = int(fields['TDO'], 16)
            self.checks += 1
            diff = (got ^ want) & pat.mask
            if diff:
                first = (diff & -diff).bit_length() - 1
                raise SvfError('line {}: {} TDO mismatch in {} of {} bits (first at bit {})'.format(
                    lineno, kind, bin(diff).count('1'), length, first))

    def _runtest(self, args, lineno):
        run_state = None
        if args and args[0] in TAP:
            run_state = args.pop(0)
        count, secs = 0, 0.0
        while args:
            tok = args.pop(0)
            if tok == 'ENDSTATE':
                args.pop(0)   # we always end in the run state
                continue
            if tok == 'MAXIMUM':
                args.pop(0); args.pop(0)
                continue
            num = float(tok)
            unit = args.pop(0)
            if unit in ('TCK', 'SCK'):
                count = int(num)
            elif unit == 'SEC':
                secs = num
            else:
                raise SvfError('line {}: RUNTEST unit {}'.format(lineno, unit))
        self.goto(run_state or 'IDLE')
        start = time.monotonic()
        self._wait_tck(count)
        left = secs - (time.monotonic() - start)
        if left > 0:
            time.sleep(left)

    def execute(self, cmd, args, lineno):
        if cmd == 'TRST':
            return
        if cmd == 'STATE':
            for s in args:
                self.goto(s)
        elif cmd == 'ENDIR':
            self.endir = args[0]
        elif cmd == 'ENDDR':
            self.enddr = args[0]
        elif cmd == 'FREQUENCY':
            if args:
                self.freq = float(args[0])
                self.actual_freq = self.port.set_speed(int(self.freq))
                self.log('FREQUENCY {:g} Hz requested, cable runs at {} Hz'.format(self.freq, self.actual_freq))
        elif cmd in self.pat:
            self._scan(cmd, args, lineno)
        elif cmd == 'RUNTEST':
            self._runtest(list(args), lineno)
        else:
            raise SvfError('line {}: unsupported command {}'.format(lineno, cmd))

    def play(self, text):
        """Run all statements of an SVF file given as a string."""
        n = 0
        for lineno, cmd, args in parse(text):
            self.execute(cmd, args, lineno)
            n += 1
        return n


def parse(text):
    """Yield (line number, command, args) per SVF statement."""
    buf, start = [], None
    for lineno, line in enumerate(text.splitlines(), 1):
        line = re.split(r'//|!', line, maxsplit=1)[0]
        if not line.strip():
            continue
        if start is None:
            start = lineno
        buf.append(line)
        while ';' in buf[-1]:
            head, tail = buf[-1].split(';', 1)
            stmt = ' '.join(buf[:-1] + [head])
            # Hex values in parentheses may span lines: drop the whitespace.
            stmt = re.sub(r'\(([^)]*)\)', lambda m: ' ' + re.sub(r'\s+', '', m.group(1)) + ' ', stmt)
            toks = stmt.split()
            if toks:
                yield start, toks[0].upper(), [t.upper() if not re.fullmatch(r'[0-9a-fA-F]+', t) else t for t in toks[1:]]
            buf = [tail] if tail.strip() else []
            start = lineno if buf else None
            if not buf:
                break
