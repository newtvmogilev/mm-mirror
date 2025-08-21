#!/bin/bash
set -euo pipefail

# ===== ПАРАМЕТРЫ =====
START_URL="${START_URL:-https://mogilev.media/}"
DEPTH="${DEPTH:-3}"
WORKDIR="/work"
BUCKET="${GCS_BUCKET:?Set env var GCS_BUCKET}"

echo "[INFO] START_URL=${START_URL} DEPTH=${DEPTH} BUCKET=${BUCKET}"

mkdir -p "$WORKDIR"

# UA и заголовки, чтобы меньше резалось по защите
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

# ===== ПРОВЕРКА ДОСТУПА К БАКЕТУ =====
echo "[INFO] Checking write access to gs://$BUCKET ..."
date -Iseconds > /tmp/_mm_mirror_probe.txt
# ВАЖНО: глобальная опция -q ставится ПЕРЕД командой cp
gsutil -q cp /tmp/_mm_mirror_probe.txt gs://"$BUCKET"/_mm_last_probe.txt
echo "[OK] Write to bucket works."

# ===== ЗЕРКАЛО САЙТА =====
echo "[INFO] Running httrack..."
httrack "$START_URL" \
  --path "$WORKDIR" \
  --mirror \
  --depth="$DEPTH" \
  --near \
  --robots=0 \
  --keep-alive \
  --sockets=8 \
  --user-agent "$UA" \
  --verbose

# Находим корневую папку дампа (mogilev.media или mogilev.media-2 и т.п.)
ROOT_DIR="$(find "$WORKDIR" -maxdepth 1 -type d -regextype posix-egrep -regex '.*/mogilev\.media(-[0-9]+)?' | head -n1)"
if [[ -z "${ROOT_DIR:-}" ]]; then
  echo "[ERROR] Cannot find mirror root under $WORKDIR"
  ls -la "$WORKDIR" || true
  exit 1
fi
echo "[INFO] Mirror root: $ROOT_DIR"

# Переписываем абсолютные ссылки на path-style GCS
echo "[INFO] Rewriting absolute links to https://storage.googleapis.com/${BUCKET}/ ..."
find "$ROOT_DIR" -type f -name "*.html" -print0 \
  | xargs -0 sed -i "s#https://mogilev\.media/#https://storage.googleapis.com/${BUCKET}/#g"

# ===== ЗАЛИВКА В БАКЕТ =====
echo "[INFO] Sync to GCS..."
gsutil -m rsync -r -d "$ROOT_DIR" "gs://$BUCKET"

echo "[DONE] Mirror uploaded to gs://$BUCKET"
