#!/bin/bash
set -euo pipefail

# -------- ПАРАМЕТРЫ --------
START_URL="${START_URL:-https://mogilev.media/}"
DEPTH="${DEPTH:-3}"
WORKDIR="/work"
BUCKET="${GCS_BUCKET:?Set env var GCS_BUCKET}"

echo "[INFO] START_URL=${START_URL}  DEPTH=${DEPTH}  BUCKET=${BUCKET}"

mkdir -p "${WORKDIR}"

# Базовый URL бакета, куда переписываем абсолютные ссылки
BUCKET_BASE="https://storage.googleapis.com/${BUCKET}/"

# User-Agent, чтобы меньше резали по антиботу
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

# -------- ПРОВЕРКА ДОСТУПА К БАКЕТУ --------
echo "[INFO] Checking write access to gs://${BUCKET} ..."
date -Iseconds > /tmp/_mm_mirror_probe.txt
gsutil cp -q /tmp/_mm_mirror_probe.txt "gs://${BUCKET}/_mm_last_probe.txt"
echo "[OK] Write to bucket works."

# -------- СКАЧИВАЕМ ЗЕРКАЛО --------
echo "[INFO] Running httrack..."
httrack "${START_URL}" \
  --path "${WORKDIR}" \
  --mirror \
  --depth="${DEPTH}" \
  --near \
  --robots=0 \
  --keep-alive \
  --sockets=8 \
  --user-agent "${UA}" \
  --verbose \
  "-*fonts.googleapis.com/*" "-*fonts.gstatic.com/*" "-*googletagmanager.com/*" "-*google-analytics.com/*"

# -------- ИЩЕМ КОРЕНЬ ДАМПА --------
ROOT_DIR="$(find "${WORKDIR}" -maxdepth 1 -type d -regextype posix-egrep -regex '.*/mogilev\.media(-[0-9]+)?' | head -n1 || true)"
if [[ -z "${ROOT_DIR:-}" ]]; then
  echo "[ERROR] Cannot find mirror root under ${WORKDIR}"
  ls -la "${WORKDIR}" || true
  exit 1
fi
echo "[INFO] Mirror root: ${ROOT_DIR}"

# -------- ПЕРЕПИСЫВАЕМ АБСОЛЮТНЫЕ ССЫЛКИ --------
echo "[INFO] Rewriting absolute links to ${BUCKET_BASE} ..."
# HTML
find "${ROOT_DIR}" -type f -name "*.html" -print0 | xargs -0 -I{} \
  sed -E -i \
    -e "s#https?://mogilev\.media/#${BUCKET_BASE//\//\\/}#g" \
    -e "s#//mogilev\.media/#${BUCKET_BASE//\//\\/}#g"

# CSS тоже могут содержать абсолютные URL: url(https://mogilev.media/...)
find "${ROOT_DIR}" -type f -name "*.css" -print0 | xargs -0 -I{} \
  sed -E -i \
    -e "s#https?://mogilev\.media/#${BUCKET_BASE//\//\\/}#g" \
    -e "s#//mogilev\.media/#${BUCKET_BASE//\//\\/}#g"

# -------- СИНХРОНИЗАЦИЯ В БАКЕТ --------
echo "[INFO] Sync to GCS..."
# Копируем содержимое корня дампа в корень бакета (без лишней папки)
gsutil -m rsync -r -d "${ROOT_DIR}" "gs://${BUCKET}"

echo "[DONE] Mirror uploaded to gs://${BUCKET}"
