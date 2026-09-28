#!/bin/sh
# Build ise:14.7-full from ise-14.7-ISE_DS.tar (see extract-from-vm.sh).
# Usage: docker/build.sh [dir]   (default ~/Downloads/xilinx)
# Keep only the tar in that directory: all of it is sent to Docker.
set -eu

dir=${1:-$HOME/Downloads/xilinx}
tar=ise-14.7-ISE_DS.tar

if [ ! -f "$dir/$tar" ]; then
    echo "missing $dir/$tar (run docker/extract-from-vm.sh first)" >&2
    exit 1
fi

cd "$(dirname "$0")"
docker build \
    --platform linux/amd64 \
    --build-context ise="$dir" \
    -f Dockerfile.full \
    -t ise:14.7-full \
    .
