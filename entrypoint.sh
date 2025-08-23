#!/bin/bash
set -euo pipefail

# ===== ПАРАМЕТРЫ =====
# По умолчанию стартуем с AMP-версии сайта
START_URL="${START_URL:-https://mogilev.media/amp/}"
# Глубина обхода (обычно 2–3 для AMP достаточно)
DEPTH="${DEPTH:-3}"
# Рабочая директория внутри контейнера
WORKDIR="/work"
# Обязательный параметр: имя GCS-бакета для зеркала
BUCKET="${GCS_BUCKET:?Set env var GCS_BUCKET}"

echo "[INFO] START_URL=${START_URL}  DEPTH=${DEPTH}  BUCKET=${BUCKET}"

mkdir -p "$WORKDIR"

# Современный UA, чтобы меньше шансов на отрезание
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

# ===== ПРОВЕРКА ДОСТУПА К БАКЕТУ =====
echo "[INFO] Checking write access to gs://${BUCKET} ..."
date -Iseconds > /tmp/_mm_mirror_probe.txt
gsutil -q cp /tmp/_mm_mirror_probe.txt "gs://${BUCKET}/_mm_last_probe.txt"
echo "[OK] Write to bucket works."

# ===== СКАЧИВАЕМ AMP-КОПИЮ САЙТА =====
echo "[INFO] Running httrack..."
# Отключаем внешние тяжёлые домены (шрифты/аналитика), оставляем только нужный хост
httrack "$START_URL" \
  --path "$WORKDIR" \
  --mirror \
  --depth="$DEPTH" \
  --robots=0 \
  --keep-alive \
  --sockets=8 \
  --user-agent "$UA" \
  --verbose \
  -"https://fonts.googleapis.com/*" \
  -"https://fonts.gstatic.com/*" \
  -"https://www.googletagmanager.com/*" \
  -"https://www.google-analytics.com/*"

# ===== ИЩЕМ КОРЕНЬ ДАМПА И ПОДСТАВЛЯЕМ AMP-ПАПКУ =====
BASE_DIR="$(find "$WORKDIR" -maxdepth 1 -type d -name 'mogilev.media*' | sort | head -n1 || true)"
if [[ -z "${BASE_DIR:-}" ]]; then
  echo "[ERROR] Cannot find mirror base dir under $WORKDIR"
  ls -la "$WORKDIR" || true
  exit 1
fi

# Если httrack сложил AMP внутрь подпапки /amp — берём её как корень публикации
if [[ -d "${BASE_DIR}/amp" ]]; then
  ROOT_DIR="${BASE_DIR}/amp"
else
  ROOT_DIR="${BASE_DIR}"
fi

echo "[INFO] Mirror base: $BASE_DIR"
echo "[INFO] Publish root: $ROOT_DIR"

# ===== ПРАВИМ ССЫЛКИ НА ПУБЛИЧНЫЙ GCS (path-style) =====
# Меняем абсолютные ссылки с сайта на CDN GCS:
# 1) https://mogilev.media/amp/...  -> https://storage.googleapis.com/<bucket>/
# 2) (на всякий) https://mogilev.media/... -> https://storage.googleapis.com/<bucket>/
echo "[INFO] Rewriting absolute links to https://storage.googleapis.com/${BUCKET}/ ..."
find "$ROOT_DIR" -type f -name "*.html" -print0 | xargs -0 sed -i \
  -e "s#https://mogilev.media/amp/#https://storage.googleapis.com/${BUCKET}/#g" \
  -e "s#https://mogilev.media/#https://storage.googleapis.com/${BUCKET}/#g"

# ===== ЗАЛИВКА В GCS =====
echo "[INFO] Sync to GCS..."
# -m параллелит, -r рекурсивно, -d удаляет в бакете то, чего нет локально (полная синхронизация)
gsutil -m rsync -r -d "$ROOT_DIR" "gs://$BUCKET"

echo "[DONE] Mirror uploaded to gs://${BUCKET}"

