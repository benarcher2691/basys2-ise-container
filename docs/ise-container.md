# ISE 14.7 container: build steps

REPORT.md Phases 1–2, made concrete. Files: `docker/`.

## Status (2026-09-28)

| Step | Status |
|---|---|
| Docker Desktop 29.8.0, Rosetta for amd64 on, disk limit ~460 GB | ✅ checked |
| Base image `ubuntu:14.04` (amd64), pinned by digest; its package archive still works | ✅ |
| 1. ISE files: extracted from AMD's ISE 14.7 VM download | ✅ `ise-14.7-ISE_DS.tar`, 12.3 GB |
| 2. Build `ise:14.7-full` | ✅ 4.5 GB image, ~6 min build |
| 3. Smoke test | ✅ all six tools start, ~35 s each (see §5) |
| 4. Licence | ✅ WebPACK licence in `~/.config/xilinx/Xilinx.lic` (feature `ISE_WebPACK`, `HOSTID=ANY`, permanent) |
| 6. Slim image `ise:14.7-s3e` | ✅ **651 MB** on disk, 158 MB compressed (full: 17.3 GB); bit-identical results in `tests/regress.sh`; `bin/ise` uses it by default |
| Blinky (`examples/blinky`) | ✅ **full flow in 237 s**: 15 slices, all constraints met (min period 4.5 ns, 220 MHz). Loaded on the board with `make prog`: DONE |

## 1. Get the ISE files

AMD's download is **`Xilinx_ISE_14.7_Win10_14.7_VM_0213_1.zip`** (16.7 GB),
the "ISE 14.7 for Windows 10" package. Despite the name, it holds a
VirtualBox VM (`ova/14.7_VM.ova`): **Oracle Linux 6.4 with ISE 14.7 already
installed** in `/opt/Xilinx/14.7/ISE_DS`. That's build `14.7_1015_1`, the
same as the Linux installer. We don't run the VM; we copy the install out of
its disk:

```sh
docker/extract-from-vm.sh      # zip in ~/Downloads → ~/Downloads/xilinx/ise-14.7-ISE_DS.tar
```

- **What it does:**
  1. Unpacks the OVA from the zip. The zip itself is only read.
  2. In a privileged arm64 Linux container, converts the VM disk to a raw
     image (on the Docker volume `ise-vm-work`).
  3. Mounts the root partition (ext4, no LVM) read-only.
  4. Tars `ISE_DS/ISE`, `common`, `.xinstall` and the settings scripts.
- **Left out:** EDK (5 GB), PlanAhead (3.6 GB) and SysGen. `settings64.sh`
  skips components that aren't there.
- **Space:** the intermediates need about 17 GB (the OVA) plus about 40 GB
  in Docker's disk. The script prints the clean-up commands at the end.
- The VM contains **no licence file**. Its first network adapter's MAC was
  `08:00:27:68:C9:35`.

The Linux installer (`Xilinx_ISE_DS_Lin_14.7_1015_1.tar`) would work too,
but it isn't needed now.

## 2. Build

```sh
docker/build.sh            # or: docker/build.sh /path/to/dir-with-the-tar
```

- Builds `ise:14.7-full` from `docker/Dockerfile.full` for linux/amd64 (run
  under Rosetta).
- The tar comes in as a named build context (`ise`) and a bind mount, and is
  unpacked to `/opt/Xilinx/14.7/ISE_DS`. The image is about 12 GB.
  Afterwards, `docker builder prune` frees the copy of the tar in the build
  cache.

## 3. Smoke test (Phase 2 exit)

```sh
docker/smoke-test.sh
```

This runs `xst`, `ngdbuild`, `map`, `par`, `trce` and `bitgen` with `-h`,
with `--network none`. Each should print `ok`.

## 4. Licence (needed for map, par, bitgen)

> **Done 2026-09-28.** AMD issued an `ISE_WebPACK` licence with
> **`HOSTID=ANY`**, so it isn't tied to a MAC after all, and ISE 14.7 accepts
> that feature name. `bin/ise` still uses the internal network and fixed MAC.
> That does no harm (still no route out) and keeps the option of a
> node-locked licence open.

Tried 2026-09-28 with no licence: `xst` and `ngdbuild` run fine, then `map`
stops with `ERROR:Security:9c - No 'ISE' nor 'WebPack' feature version
2013.10 was available for part 'xc3s100e'`. The WebPACK licence is free, but
it's node-locked to a host ID.

**The container's host ID is `0242AC15E301`.** `bin/ise` always runs the
container on the internal Docker network `ise-internal` with MAC
`02:42:ac:15:e3:01`: `eth0` exists, but there's no route out (DNS fails).
Check it with `bin/ise lmutil lmhostid`. With `--network none` there's no
`eth0` and the host ID is `000000000000`, so that setting can't be used.

Getting it (needs Ben's AMD account):

1. Open https://www.xilinx.com/getlicense and sign in (it redirects to
   AMD's Product Licensing site).
2. **Create New Licenses** → under *Certificate Based Licenses*, tick
   **ISE WebPACK License** → **Generate Node-Locked License**.
3. Host: add a new host with **Host ID type: Ethernet MAC**, value
   **`0242AC15E301`**, name e.g. `basys2-ise-container`. Then **Next →
   Next** to generate it.
4. Download `Xilinx.lic` (it's also e-mailed) and save it as
   **`~/.config/xilinx/Xilinx.lic`**:
   ```sh
   mkdir -p ~/.config/xilinx && mv ~/Downloads/Xilinx.lic ~/.config/xilinx/
   ```
   `bin/ise` mounts it read-only when it's there. It's never committed
   (`*.lic` is gitignored).
5. Build and load the example:
   ```sh
   make -C examples/blinky && make -C examples/blinky prog
   ```

## 5. Known issue: slow tool start-up

Every ISE tool takes **about 35 s to start** under Rosetta, even for `-h`.
The actual work is fast: XST reports 3 s and ngdbuild 2 s for the blinky.
What was tested (2026-09-28):

| Test | Result |
|---|---|
| Network (`none`, internal, bridge), licence path, open-files limit | no effect |
| Time in the dynamic loader (`LD_DEBUG=statistics`) | milliseconds; not the cause |
| CPU split | ~29 s user, ~7 s system: ISE's own start-up code |
| Same binary under QEMU (user-mode, chroot) | 73 s, so Rosetta is the faster emulator |
| `bin/lin64/<tool>` wrapper | did the same ~35 s of start-up work again before running `unwrapped/<tool>`, and otherwise only prepends paths that are already set |

**Fix applied:** the entrypoint puts `unwrapped/` first on `PATH`, which
halves the time (70 s → 35 s per tool). The blinky flow now reaches `map` in
under 2 minutes; a full build should take about 4 minutes. The remaining
35 s is ISE's own initialisation under emulation.

## 6. Slim image `ise:14.7-s3e` (Phase 6)

```sh
docker/trace-files.sh                          # record the files the flows open → docker/keep-list.txt (~28 min)
docker/build.sh s3e                            # ise:14.7-s3e from ise:14.7-full + keep-list.txt (~10 s)
tests/regress.sh compare trace ise:14.7-s3e    # rebuild everything with it and compare (~28 min)
```

- **How the files were found:** `strace` doesn't work under Rosetta (no
  ptrace). So a native arm64 container watches the ISE container's
  `/opt/Xilinx` with **inotify** (through `/proc/<pid>/root`), while
  `tests/regress.sh trace` runs every flow in that container (`bin/ise` with
  `ISE_EXEC`).
- **What the flows cover:**
  - blinky with XST and with yosys
  - kronometer5 and nand2tetris (VHDL, the latter with IP-core netlists)
  - `projects/kronometer` with XST and with yosys
  - `projects/hack` with XST and with yosys (block RAMs from `$readmemb`)
  - the flash chain (`bitgen` CClk, `promgen`, iMPACT SVF)
  - XST syntax errors in Verilog and VHDL
  - `-h` for every tool
- **Result (2026-09-28):** 1,336 paths, 234 MB unpacked. The image is
  **651 MB on disk** (Docker's "content size", i.e. compressed: 158 MB).
  324 MB of that is the Ubuntu base and libraries it shares with the full
  image, so it adds 328 MB of its own; the ISE files are a 246 MB layer.
  The four bitstreams match the full image's bit for bit (header with the
  build date excluded), and so do the PROM image and the XST error messages.
- **Refreshed 2026-09-29** for the Verilog projects: 1,338 paths. The two new
  ones, `ISE/data/prophex.acd` and `propbin.acd`, are what edif2ngd needs to
  read hex and binary properties (LUT and block-RAM contents) in yosys
  netlists. All eight bitstreams match the full image's.
- **One gap the trace can't see:** bitgen checks that the `bin/lin64/wbtc`
  wrapper *exists* (a `stat`, invisible to inotify) before starting
  WebTalk. `Dockerfile.s3e` therefore keeps the wrapper of every kept
  `unwrapped/` tool.
- **If a new design needs something that isn't in the image** (e.g. another
  kind of IP core, or a tool not used yet): run it with
  `ISE_IMAGE=ise:14.7-full`, add it to `tests/regress.sh`, then re-run the
  trace and the rebuild. The full image stays the reference.
- **Start-up time is unchanged** (~35 s per tool). It's CPU, not file access.
