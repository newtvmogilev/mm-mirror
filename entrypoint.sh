#!/bin/bash
set -e

: "${START_URL:=https://mogilev.media/}"
: "${DEPTH:=3}"
: "${GCS_BUCKET:?Set env var GCS_BUCKET}"

echo "[INFO] START_URL=${START_URL}  DEPTH=${DEPTH}  BUCKET=${GCS_BUCKET}"

echo "[INFO] Checking write access to gs://${GCS_BUCKET} ..."
echo "probe" | gsutil cp - "gs://${GCS_BUCKET}/_mm_last_probe.txt"
echo "[OK] Write to bucket works."

echo "[INFO] Running httrack..."
httrack "${START_URL}" \
    -O /work \
    -w -r${DEPTH} -n -s0 -%k -c8 \
    -F "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36" \
    -*.woff -*.woff2 -*.ttf -*.eot \
    -*googleapis.com/* -*gstatic.com/* -*googletagmanager.com/* -*google-analytics.com/* \
    +*mogilev.media/*amp* \
    +*mogilev.media/wp-content/uploads/*

echo "[INFO] Uploading mirrored files to gs://${GCS_BUCKET} ..."
gsutil -m cp -r /work/* "gs://${GCS_BUCKET}/"

echo "[INFO] Mirror job finished successfully."



