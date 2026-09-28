#!/bin/sh
# Reference builds for the ISE image (REPORT.md Phase 6).
#
#   tests/regress.sh trace     run every flow once (used by docker/trace-files.sh)
#   tests/regress.sh compare [imageA] [imageB]
#                              build everything with both images and check the
#                              bitstreams are identical (header, which holds the
#                              build date, excluded) and the error paths match.
#                              Defaults: ise:14.7-full ise:14.7-s3e
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
mode=${1:-compare}
out=$root/.regress

# name:dir:make-args
projects="
blinky:examples/blinky:
blinky-yosys:examples/blinky:SYNTH=yosys
kronometer5:legacy/kronometer5:
nand2tetris:legacy/nand2tetris:
"

run_all() {   # $1 = result dir; uses ISE_IMAGE / ISE_EXEC from the environment
    dest=$1; mkdir -p "$dest"
    echo "$projects" | while IFS=: read -r name dir args; do
        [ -n "$name" ] || continue
        echo "== $name"
        make -s -C "$root/$dir" clean
        make -s -C "$root/$dir" $args > "$dest/$name.log" 2>&1 ||
            { tail -20 "$dest/$name.log"; echo "FAIL $name"; exit 1; }
        b=build; [ "$args" = "SYNTH=yosys" ] && b=build-yosys
        top=$(ls "$root/$dir/$b"/*.bit | grep -v _prom | head -1)
        cp "$top" "$dest/$name.bit"
    done
    echo "== flash chain (bitgen CClk, promgen, impact)"
    make -s -C "$root/examples/blinky" build/top_flash.svf > "$dest/flash.log" 2>&1 ||
        { tail -20 "$dest/flash.log"; echo "FAIL flash"; exit 1; }
    cp "$root/examples/blinky/build/top.mcs" "$dest/blinky.mcs"
    echo "== error paths"
    (cd "$root/tests/errors" &&
        for f in bad.v bad.vhd; do
            case $f in *.vhd) l=vhdl ;; *) l=verilog ;; esac
            echo "$l work $f" > bad.prj
            printf 'run\n-ifn bad.prj\n-ifmt mixed\n-top bad\n-ofn bad.ngc\n-p xc3s100e-cp132-4\n' > bad.xst
            "$root/bin/ise" xst -ifn bad.xst -ofn bad.syr > /dev/null 2>&1 || true
            grep -E '^ERROR' bad.syr | sed 's/"[^"]*"//g' > "$dest/errors-$f.txt"
            [ -s "$dest/errors-$f.txt" ] || { echo "FAIL: no XST error for $f"; exit 1; }
        done
        rm -rf bad.prj bad.xst bad.syr bad.ngc bad.lso xst _xmsgs *.xrpt)
    echo "== tools start"
    "$root/bin/ise" bash -c 'for t in xst ngdbuild map par trce bitgen promgen impact; do
        $t -h 2>&1 | grep -m1 -E "Release 14.7|iMPACT" >/dev/null || { echo "FAIL $t"; exit 1; }; done' \
        > "$dest/tools.log" 2>&1 || { cat "$dest/tools.log"; exit 1; }
}

strip_header() {   # bitstream from the sync word AA995566 on
    python3 -c 'import sys; d=open(sys.argv[1],"rb").read(); sys.stdout.buffer.write(d[d.index(b"\xaa\x99\x55\x66"):])' "$1"
}

case $mode in
    trace)
        run_all "$out/trace" ;;
    compare)
        a=${2:-ise:14.7-full}; b=${3:-ise:14.7-s3e}
        rm -rf "$out/a" "$out/b"
        echo "### $a"; ISE_IMAGE=$a run_all "$out/a"
        echo "### $b"; ISE_IMAGE=$b run_all "$out/b"
        fail=0
        for f in "$out"/a/*.bit; do
            n=$(basename "$f")
            if [ "$(strip_header "$f" | shasum)" = "$(strip_header "$out/b/$n" | shasum)" ]; then
                echo "same  $n"
            else
                echo "DIFF  $n"; fail=1
            fi
        done
        for f in "$out"/a/errors-*.txt "$out"/a/blinky.mcs; do
            n=$(basename "$f")
            if cmp -s "$f" "$out/b/$n"; then echo "same  $n"; else echo "DIFF  $n"; fail=1; fi
        done
        [ $fail -eq 0 ] && echo "REGRESSION OK: $a and $b give identical results" ||
            { echo "REGRESSION FAILED"; exit 1; } ;;
    *)
        echo "usage: $0 trace | compare [imageA] [imageB]" >&2; exit 2 ;;
esac
