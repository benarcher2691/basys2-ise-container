#!/bin/sh
# Build ise:14.7-full from the ISE 14.7 Linux installer tarball.
# Usage: docker/build.sh [installer-dir]   (default ~/Downloads/xilinx)
# Keep only the tarball in that directory: all of it is sent to Docker.
set -eu

dir=${1:-$HOME/Downloads/xilinx}
tar=Xilinx_ISE_DS_Lin_14.7_1015_1.tar

if [ ! -f "$dir/$tar" ]; then
    echo "missing $dir/$tar (see docs/ise-container.md, step 1)" >&2
    exit 1
fi

cd "$(dirname "$0")"
docker build \
    --platform linux/amd64 \
    --build-context installer="$dir" \
    -f Dockerfile.full \
    -t ise:14.7-full \
    .
