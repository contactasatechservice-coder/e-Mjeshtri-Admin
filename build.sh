#!/usr/bin/env bash
set -euo pipefail
rm -rf dist site.zip payload.b64
mkdir -p dist
cat parts/part_* > payload.b64
base64 -d payload.b64 > site.zip
unzip -q site.zip -d dist
rm -f payload.b64 site.zip