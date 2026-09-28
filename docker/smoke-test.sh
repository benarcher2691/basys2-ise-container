#!/bin/sh
# Phase 2 exit check: every back-end tool starts and prints its help,
# with no network. Usage: docker/smoke-test.sh [image]
set -eu

image=${1:-ise:14.7-full}

docker run --rm --platform linux/amd64 --network none "$image" bash -c '
    status=0
    for tool in xst ngdbuild map par trce bitgen; do
        # Judge by the output: ngdbuild and map exit non-zero after -h.
        start=$(date +%s)
        out=$("$tool" -h 2>&1) || true
        secs=$(( $(date +%s) - start ))
        if echo "$out" | grep -qiE "Release 14\.7|^usage|^$tool:"; then
            echo "ok    $tool (${secs}s): $(echo "$out" | grep -m1 -E "Release" || echo "help printed")"
        else
            echo "FAIL  $tool (${secs}s)"; echo "$out" | tail -5; status=1
        fi
    done
    exit $status
'
