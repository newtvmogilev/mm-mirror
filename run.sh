#!/bin/bash
set -euo pipefail

TARGET="https://mogilev.media"
OUT="/tmp/mirror"

echo "[1/5] HTTrack start"
httrack "$TARGET" \
  -O "$OUT" \
  "+*.mogilev.media/*" \
  "-*logout*" "-*wp-admin*" \
  -v -s0 -%v

echo "[2/5] Mirror top-level listing:"
find "$OUT" -maxdepth 2 -type f | head -n 30 || true

echo "[3/5] gsutil version:"
gsutil version -l || true

echo "[4/5] Check bucket access (list):"
gsutil ls gs://m-media || true

echo "[5/5] Sync to bucket:"
gsutil -m rsync -r "$OUT" gs://m-media

echo "[DONE] Sync finished"
