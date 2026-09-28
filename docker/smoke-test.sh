#!/bin/sh
# Phase 2 exit check: every back-end tool starts and prints its help,
# with no network. Usage: docker/smoke-test.sh [image]
set -eu

image=${1:-ise:14.7-full}

docker run --rm --platform linux/amd64 --network none "$image" bash -c '
    status=0
    for tool in xst ngdbuild map par trce bitgen; do
        if out=$("$tool" -h 2>&1); then
            echo "ok    $tool: $(echo "$out" | grep -m1 -E "Release|Xilinx|Usage" || true)"
        else
            echo "FAIL  $tool"; echo "$out" | tail -5; status=1
        fi
    done
    exit $status
'
