#!/bin/bash
set -Eeuo pipefail

echo "[SCRIPT] mm-mirror v2025-08-23a"

# -------- ПАРАМЕТРЫ --------
START_URL="${START_URL:-https://mogilev.media/}"
DEPTH="${DEPTH:-3}"
BUCKET="${GCS_BUCKET:?Set env var GCS_BUCKET}"
WORKDIR="/work"

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

echo "[INFO] START_URL=${START_URL}  DEPTH=${DEPTH}  BUCKET=${BUCKET}"

mkdir -p "$WORKDIR"

# -------- ПРОБА ЗАПИСИ В БАКЕТ --------
echo "[INFO] Checking write access to gs://${BUCKET} ..."
date -Iseconds | gsutil -q cp - "gs://${BUCKET}/_mm_last_probe.txt"
echo "[OK] Write to bucket works."

# -------- МИРОВАНИЕ --------
echo "[INFO] Running httrack..."
httrack "$START_URL" \
  --path "$WORKDIR" \
  --mirror \
  --depth="$DEPTH" \
  --robots=0 \
  --keep-alive \
  --sockets=8 \
  --user-agent "$UA" \
  --verbose

# -------- ПОИСК КОРНЯ ДАМПА --------
ROOT_DIR="$(find "$WORKDIR" -maxdepth 1 -type d -regextype posix-egrep -regex '.*/mogilev\.media(-[0-9]+)?' | head -n1)"
if [[ -z "${ROOT_DIR:-}" ]]; then
  echo "[WARN] Cannot find mogilev.media* folder under $WORKDIR, will use $WORKDIR itself"
  ROOT_DIR="$WORKDIR"
fi
echo "[INFO] Mirror root: $ROOT_DIR"
echo "[INFO] Files under root: $(find "$ROOT_DIR" -type f | wc -l)"

# -------- ПОЛНАЯ ЗАЛИВКА В БАКЕТ --------
echo "[INFO] Uploading to gs://${BUCKET} via rsync..."
gsutil -m rsync -r -d "$ROOT_DIR" "gs://${BUCKET}"

echo "[DONE] Mirror uploaded to gs://${BUCKET}"
