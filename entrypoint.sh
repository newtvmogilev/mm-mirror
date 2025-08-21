#!/bin/bash
set -euo pipefail

START_URL="${START_URL:-https://mogilev.media/}"
DEPTH="${DEPTH:-3}"
WORKDIR="/work"
BUCKET="${GCS_BUCKET:?Set env var GCS_BUCKET}"

mkdir -p "$WORKDIR"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

# Полное зеркало с httrack
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

ROOT_DIR="$WORKDIR/$(echo "$START_URL" | sed -E 's#https?://##' | sed 's#/.*##')"

# Переписываем абсолютные ссылки на path‑style GCS
find "$ROOT_DIR" -type f -name "*.html" -print0 | xargs -0 sed -i "s#https://mogilev.media/#https://storage.googleapis.com/${BUCKET}/#g"

# Синхронизация в бакет (доступ публичный уже дан на уровне бакета)
gsutil -m rsync -r -d "$ROOT_DIR" "gs://$BUCKET"

echo "Mirror uploaded to gs://$BUCKET"
