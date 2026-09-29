#!/bin/sh
# Build the report: out/report.html (one self-contained web page) and
# out/report.pdf (LaTeX via tectonic). Needs pandoc and tectonic
# (brew install pandoc tectonic).
# Usage: report/build.sh [html|pdf]   (default: both)
set -eu

cd "$(dirname "$0")"
mkdir -p out
chapters=$(ls chapters/*.md | sort)
what=${1:-all}

if [ "$what" = all ] || [ "$what" = html ]; then
    pandoc metadata.yaml $chapters \
        --standalone --embed-resources --css style.css \
        --number-sections --toc --toc-depth=2 \
        --syntax-highlighting=pygments \
        -o out/report.html
    echo "out/report.html"
fi

if [ "$what" = all ] || [ "$what" = pdf ]; then
    pandoc metadata.yaml $chapters \
        --pdf-engine=tectonic \
        --syntax-highlighting=tango \
        -o out/report.pdf
    echo "out/report.pdf"
fi
