#!/bin/bash
set -euo pipefail

# ===== ПАРАМЕТРЫ =====
START_URL="${START_URL:-https://mogilev.media/}"
DEPTH="${DEPTH:-3}"
WORKDIR="/work"
# ВАЖНО: переменная окружения должна называться GCS_BUCKET (в Cloud Run Job)
BUCKET="${GCS_BUCKET:?Set env var GCS_BUCKET}"

echo "[INFO] START_URL=${START_URL} DEPTH=${DEPTH} BUCKET=${BUCKET}"

mkdir -p "$WORKDIR"

# UA и заголовки
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

# ===== ПРОВЕРКА ДОСТУПА К БАКЕТУ =====
echo "[INFO] Checking write access to gs://$BUCKET ..."
date -Iseconds > /tmp/_mm_mirror_probe.txt
gsutil -q cp /tmp/_mm_mirror_probe.txt "gs://$BUCKET/_mm_last_probe.txt"
echo "[OK] Write to bucket works."

# ===== ЗЕРКАЛО САЙТА =====
echo "[INFO] Running httrack..."
# Ключи:
#  --path: всё ляжет в /work
#  --robots=0: игнорируем robots.txt (иначе может сильно урезать)
#  --near: тянем необходимые ресурсы
#  --sockets/-c8: параллельность
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

echo "[INFO] httrack finished. Listing $WORKDIR ..."
# Показать, что накачалось рядом с корнем
find "$WORKDIR" -maxdepth 2 -type d -print | sed 's/^/[DIR] /'
find "$WORKDIR" -maxdepth 2 -type f -name 'index.html' -print | sed 's/^/[FILE] /'

# Пытаемся найти корень дампа по разным шаблонам
ROOT_DIR="$(find "$WORKDIR" -maxdepth 1 -type d -regextype posix-egrep -regex '.*/(www\.)?mogilev\.media(-[0-9]+)?' | head -n1)"

# Если не нашли по домену — берём первую папку внутри /work (fallback)
if [[ -z "${ROOT_DIR:-}" ]]; then
  ROOT_DIR="$(find "$WORKDIR" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
fi

if [[ -z "${ROOT_DIR:-}" ]]; then
  echo "[ERROR] Mirror root not found. Current /work content:"
  ls -la "$WORKDIR" || true
  exit 1
fi

echo "[INFO] Mirror root: $ROOT_DIR"
ls -la "$ROOT_DIR" || true

# Переписываем абсолютные ссылки на path‑style GCS (оба варианта: с www и без)
echo "[INFO] Rewriting absolute links to https://storage.googleapis.com/${BUCKET}/ ..."
find "$ROOT_DIR" -type f -name "*.html" -print0 \
  | xargs -0 sed -i \
    -e "s#https://mogilev\.media/#https://storage.googleapis.com/${BUCKET}/#g" \
    -e "s#https://www\.mogilev\.media/#https://storage.googleapis.com/${BUCKET}/#g"

# ===== ЗАЛИВКА В БАКЕТ =====
echo "[INFO] Sync to GCS (this may take a while)..."
gsutil -m rsync -r -d "$ROOT_DIR" "gs://$BUCKET"

echo "[DONE] Mirror uploaded to gs://$BUCKET"


