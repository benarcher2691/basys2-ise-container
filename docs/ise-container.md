# ISE 14.7 container: build steps

REPORT.md Phases 1–2, made concrete. Files: `docker/`.

## Status (2026-09-28)

| Step | Status |
|---|---|
| Docker Desktop 29.8.0, Rosetta for amd64 on, disk limit ~460 GB | ✅ checked |
| Base image `ubuntu:14.04` (amd64), pinned by digest; its package archive still works | ✅ |
| 1. ISE files: extracted from AMD's ISE 14.7 VM download | ✅ `ise-14.7-ISE_DS.tar`, 12.3 GB |
| 2. Build `ise:14.7-full` | ✅ 4.5 GB image, ~6 min build |
| 3. Smoke test | ✅ all six tools start (but slowly, see below) |
| 4. Licence | ⛔ **needed**: `xst` and `ngdbuild` run without one, `map` refuses. **Ben:** get it (steps below) |
| Blinky (`examples/blinky`) | ✅ synthesised (16 slices) and translated; stops at `map` until the licence is in place |

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

Every ISE tool takes **about 70 s to start** under Rosetta, even for `-h`.
The actual work is fast: XST reports 3 s and ngdbuild 2 s for the blinky.
The time is CPU-bound, split about evenly between the small `bin/lin64/<tool>`
wrapper and the real `unwrapped/<tool>`. It isn't the network, the licence
lookup or the open-files limit (all tested). The likely cause is Rosetta
translating ISE's large libraries on every launch. To try later: Rosetta's
translation cache, QEMU for comparison, and calling `unwrapped/` directly.
A full flow of six tools therefore takes about 7 minutes.
