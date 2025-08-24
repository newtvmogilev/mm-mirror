#!/bin/bash
set -euo pipefail

export LANG=C
export LC_ALL=C

# ========= ПАРАМЕТРЫ =========
START_URL="${START_URL:-https://mogilev.media/}"
DEPTH="${DEPTH:-3}"
WORKDIR="/work"

# Обязательная переменная окружения из Cloud Run Job
BUCKET="${GCS_BUCKET:?Set env var GCS_BUCKET}"

echo "[INFO] START_URL=${START_URL} DEPTH=${DEPTH} BUCKET=${BUCKET}"

mkdir -p "$WORKDIR"

# User-Agent — ближе к обычному Chrome
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

# ========= ПРОВЕРКА ДОСТУПА К БАКЕТУ =========
echo "[INFO] Checking write access to gs://$BUCKET ..."
date -Iseconds > /tmp/_mm_mirror_probe.txt
gsutil cp -q /tmp/_mm_mirror_probe.txt "gs://$BUCKET/_mm_last_probe.txt"
echo "[OK] Write to bucket works."

# ========= ЗЕРКАЛО САЙТА =========
# ВАЖНО: исключаем сторонние домены (Google Fonts/Analytics и т.п.) — сайт будет работать и без них
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
  --ext-depth=0 \
  --stay-on-same-host \
  --stay-on-same-domain \
  "-*.woff" "-*.woff2" "-*.ttf" "-*.eot" \
  "-https://fonts.googleapis.com/*" \
  "-https://fonts.gstatic.com/*" \
  "-https://www.googletagmanager.com/*" \
  "-https://www.google-analytics.com/*" \
  --verbose

# Находим корневую папку дампа (обычно $WORKDIR/mogilev.media или с суффиксом -2/-3)
ROOT_DIR="$(find "$WORKDIR" -maxdepth 1 -type d -regextype posix-egrep -regex '.*/mogilev\.media(-[0-9]+)?' | head -n1 || true)"
if [[ -z "${ROOT_DIR:-}" ]]; then
  echo "[ERROR] Cannot find mirror root under $WORKDIR"
  ls -la "$WORKDIR" || true
  exit 1
fi
echo "[INFO] Mirror root: $ROOT_DIR"

# ========= ПЕРЕПИСЬ АБСОЛЮТНЫХ ССЫЛОК =========
# Сайт лежит внутри подпапки 'mogilev.media/' в бакете,
# поэтому все абсолютные ссылки на https://mogilev.media/... должны стать
# https://storage.googleapis.com/<BUCKET>/mogilev.media/...
BUCKET_HOST="https://storage.googleapis.com/${BUCKET}/mogilev.media/"

echo "[INFO] Rewriting absolute links to ${BUCKET_HOST} ..."
# 1) https://mogilev.media/..... -> https://storage.googleapis.com/<bucket>/mogilev.media/.....
find "$ROOT_DIR" -type f -name "*.html" -print0 | \
  xargs -0 sed -i -E "s#https?://mogilev\.media/#${BUCKET_HOST//\//\\/}#g"

# 2) //mogilev.media/..... -> https://storage.googleapis.com/<bucket>/mogilev.media/.....
find "$ROOT_DIR" -type f -name "*.html" -print0 | \
  xargs -0 sed -i -E "s#//mogilev\.media/#${BUCKET_HOST//\//\\/}#g"

# (опционально) правим canonical, если в теме WP он абсолютный
find "$ROOT_DIR" -type f -name "*.html" -print0 | \
  xargs -0 sed -i -E "s#(<link[^>]+rel=\"canonical\"[^>]+href=\")https?://mogilev\.media/#\1${BUCKET_HOST//\//\\/}#g"

# ========= ВЫГРУЗКА В БАКЕТ =========
# Синхронизируем корневую папку зеркала (внутри которой директорий mogilev.media/ и файлы)
# в корень бакета. В итоге в бакете будет объектная папка 'mogilev.media/...'
echo "[INFO] Sync to GCS..."
gsutil -m rsync -r -d "$ROOT_DIR" "gs://$BUCKET"

echo "[DONE] Mirror uploaded to gs://$BUCKET"
