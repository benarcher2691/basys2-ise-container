#!/bin/sh
# Phase 6: record which files under /opt/Xilinx the ISE flows open, to make
# docker/keep-list.txt for the slim image. strace doesn't work under Rosetta,
# so a native arm64 container watches the ISE container's filesystem with
# inotify (through /proc/<pid>/root) while tests/regress.sh runs the
# reference builds through it (bin/ise with ISE_EXEC).
# Usage: docker/trace-files.sh      (board not needed)
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
name=ise-trace
out=$root/docker/keep-list.txt
tmp=$root/.trace
rm -rf "$tmp" && mkdir -p "$tmp"

docker rm -f "$name" ise-tracer >/dev/null 2>&1 || true
docker network inspect ise-internal >/dev/null 2>&1 ||
    docker network create --internal ise-internal >/dev/null
docker run -d --name "$name" --platform linux/amd64 \
    --network ise-internal --mac-address 02:42:ac:15:e3:01 \
    -v "$root":/work -v "$HOME/.config/xilinx/Xilinx.lic":/root/.Xilinx/Xilinx.lic:ro \
    --entrypoint sleep ise:14.7-full infinity >/dev/null

docker run -d --name ise-tracer --privileged --platform linux/arm64 \
    --pid=container:"$name" -v "$tmp":/out ubuntu:24.04 bash -c '
        apt-get update -qq >/dev/null && apt-get install -y -qq inotify-tools >/dev/null
        sysctl -qw fs.inotify.max_user_watches=1048576
        inotifywait -m -r -e open --format "%w%f" /proc/1/root/opt/Xilinx \
            -o /out/opens.raw 2>/out/inotify.err &
        until grep -q "Watches established" /out/inotify.err; do sleep 1; done
        touch /out/ready
        wait' >/dev/null

echo "waiting for inotify watches..."
until [ -f "$tmp/ready" ]; do sleep 2; done

ISE_EXEC=$name "$root/tests/regress.sh" trace

sleep 2
docker rm -f ise-tracer "$name" >/dev/null
sed 's|^/proc/1/root||' "$tmp/opens.raw" | sort -u > "$tmp/opens.txt"
{
    echo "# Files under /opt/Xilinx opened by tests/regress.sh (docker/trace-files.sh)."
    echo "# Generated $(date +%Y-%m-%d); input for docker/Dockerfile.s3e."
    cat "$tmp/opens.txt"
} > "$out"
echo "$(grep -vc '^#' "$out") paths -> $out"
