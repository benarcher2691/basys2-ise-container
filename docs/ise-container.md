# ISE 14.7 container: build steps

REPORT.md Phases 1–2, made concrete. Files: `docker/`.

## Status (2026-09-28)

| Step | Status |
|---|---|
| Docker Desktop 29.8.0, Rosetta for amd64 on, disk limit ~460 GB | ✅ checked |
| Base image `ubuntu:14.04` (amd64), pinned by digest; its package archive still works | ✅ |
| Dockerfile, install config, entrypoint, build and smoke-test scripts | ✅ written; tried up to the installer step |
| 1. Download the installer | ⬜ **Ben** (needs an AMD account) |
| 2. Build `ise:14.7-full` | ⬜ |
| 3. Smoke test | ⬜ |
| 4. Licence | ⬜ (first check whether one is needed at all) |

## 1. Download the installer (manual)

1. On amd.com, go to **Support → Downloads → Adaptive SoCs & FPGAs → Legacy
   ISE → 14.7**. Pick the **Linux** "Full Installer" (TAR), about 6 GB, file
   `Xilinx_ISE_DS_Lin_14.7_1015_1.tar`. It needs an AMD account and an
   export-compliance form.
2. Put it on its own in `~/Downloads/xilinx/`. The build sends everything in
   that directory to Docker.
3. Check it against the checksum shown on the download page (the page loads
   its content with JavaScript, so it can't be scripted from here):
   ```sh
   md5 ~/Downloads/xilinx/Xilinx_ISE_DS_Lin_14.7_1015_1.tar
   ```
   Note the value here once it's verified: `<md5>`

## 2. Build

```sh
docker/build.sh            # or: docker/build.sh /path/to/installer-dir
```

- Builds `ise:14.7-full` from `docker/Dockerfile.full`, for linux/amd64
  under Rosetta.
- The tarball comes in as a named build context and a bind mount. It's
  extracted, installed and deleted in one step, so neither the tarball nor
  the extracted files end up in a layer.
- The install config (`docker/install.cfg`) selects WebPACK only. The licence
  manager, cable drivers and environment setup are all off.
- Expect about 20 GB of image and an unattended run of roughly an hour.
  Afterwards, `docker builder prune` frees the build cache.

## 3. Smoke test (Phase 2 exit)

```sh
docker/smoke-test.sh
```

This runs `xst`, `ngdbuild`, `map`, `par`, `trce` and `bitgen` with `-h`,
with `--network none`. Each should print `ok`.

## 4. Licence and network

- **Try without a licence first.** The XC3S100E is a WebPACK part. Run the
  Phase 3 flow and see whether any tool complains about a licence. If none
  does, skip the rest of this section.
- **If a licence is needed,** it's node-locked to a MAC address. That doesn't
  work with `--network none`: the container then has **no `eth0` and no
  MAC** (checked 2026-09-28). Use an **internal Docker network** instead. It
  gives the container an `eth0` with a fixed MAC but no route out (also
  checked: DNS fails).
  ```sh
  docker network create --internal ise-internal     # once (already created)
  docker run --rm --network ise-internal --mac-address 02:42:ac:15:e3:01 \
      -v ~/.config/xilinx/Xilinx.lic:/root/.Xilinx/Xilinx.lic:ro \
      ise:14.7-full <tool> ...
  ```
  Request the WebPACK licence from AMD's licensing site for host ID
  `02:42:ac:15:e3:01` (the site takes it without colons), and store it at
  `~/.config/xilinx/Xilinx.lic`. It's never committed, since `*.lic` is
  gitignored.
