#!/bin/bash
set -u  # убрали -e, чтобы не падать на кодах HTTrack

TARGET="https://mogilev.media"
OUT="/tmp/mirror"

echo "[1/6] HTTrack start"
httrack "$TARGET" \
  -O "$OUT" \
  "+*.mogilev.media/*" \
  "-*logout*" "-*wp-admin*" \
  -v -s0 -%v
HTCODE=$?; echo "[2/6] HTTrack finished with code=$HTCODE (0=ok)."

echo "[3/6] Mirror listing (top 40 files)"
find "$OUT" -maxdepth 3 -type f | head -n 40 || true

echo "[4/6] gsutil info"; gsutil version -l || true
echo "[5/6] Check bucket access"; gsutil ls gs://m-media || true

echo "[6/6] Sync to bucket"
gsutil -m rsync -r "$OUT" gs://m-media

echo "[DONE] Sync finished"
