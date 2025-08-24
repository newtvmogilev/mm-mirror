#!/bin/bash
set -euo pipefail

# ===== ПАРАМЕТРЫ, которые можно переопределять переменными окружения =====
START_URL="${START_URL:-https://mogilev.media/}"
DEPTH="${DEPTH:-3}"
WORKDIR="/work"
BUCKET="${GCS_BUCKET:?Set env var GCS_BUCKET}"

echo "[INFO] START_URL=${START_URL}  DEPTH=${DEPTH}  BUCKET=${BUCKET}"

# Рабочая папка
mkdir -p "$WORKDIR"

# User‑Agent, похожий на Chrome
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

# ===== ПРОВЕРКА ДОСТУПА К БАКЕТУ =====
echo "[INFO] Checking write access to gs://${BUCKET} ..."
date -Iseconds > /tmp/_mm_mirror_probe.txt
gsutil cp -q /tmp/_mm_mirror_probe.txt "gs://${BUCKET}/_mm_last_probe.txt"
echo "[OK] Write to bucket works."

# ===== ЗЕРКАЛО САЙТА (без агрессивных фильтров доменов) =====
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
  --verbose

# Находим корень дампа: mogilev.media или mogilev.media-2 и т.п.
ROOT_DIR="$(find "${WORKDIR}" -maxdepth 1 -type d -regextype posix-egrep -regex '.*/mogilev\.media(-[0-9]+)?' | head -n1)"
if [[ -z "${ROOT_DIR:-}" ]]; then
  echo "[ERROR] Cannot find mirror root under ${WORKDIR}"
  ls -la "${WORKDIR}" || true
  exit 1
fi
echo "[INFO] Mirror root: ${ROOT_DIR}"

# ===== (ОПЦИОНАЛЬНО) МИН. ПРАВКИ ВНУТРИ HTML =====
# Ничего не переписываем агрессивно, чтобы не ломать верстку.
# Если позже потребуется — можно точечно заменить ссылки.

# ===== ЗАЛИВКА В GCS (надёжно через rsync) =====
echo "[INFO] Sync to GCS (rsync)..."
# -m: параллельно; -r: рекурсивно; -d: удалять в бакете то, чего нет локально
# Cache-Control по желанию (пример: час)
gsutil -m -h "Cache-Control:public, max-age=3600" rsync -r -d "${ROOT_DIR}" "gs://${BUCKET}"

echo "[DONE] Mirror uploaded to gs://${BUCKET}"

