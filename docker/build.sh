#!/bin/sh
# Build ise:14.7-full from ise-14.7-ISE_DS.tar (see extract-from-vm.sh),
# or ise:14.7-s3e, the trimmed image, from ise:14.7-full and keep-list.txt.
# Usage: docker/build.sh [dir]   (default ~/Downloads/xilinx)
#        docker/build.sh s3e
# Keep only the tar in that directory: all of it is sent to Docker.
set -eu

if [ "${1:-}" = s3e ]; then
    cd "$(dirname "$0")"
    exec docker build --platform linux/amd64 -f Dockerfile.s3e -t ise:14.7-s3e .
fi

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
