#!/bin/bash
set -euo pipefail

START_URL="${START_URL:-https://mogilev.media/}"
DEPTH="${DEPTH:-3}"
BUCKET="${GCS_BUCKET:?Set env var GCS_BUCKET}"
WORKDIR="/work"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

echo "[INFO] START_URL=$START_URL DEPTH=$DEPTH BUCKET=$BUCKET"
mkdir -p "$WORKDIR"

# Проверка доступа
date -Iseconds > /tmp/_mm_probe.txt
gsutil cp -q /tmp/_mm_probe.txt "gs://${BUCKET}/_mm_last_probe.txt" || {
  echo "[ERR] no write to bucket"; exit 1; }

# Фильтры: докачиваем внешнюю статику, вырезаем аналитику/мусор/бесконечные ссылки
read -r -d '' FILTERS <<'EOF' || true
+*.css +*.js +*.png +*.jpg +*.jpeg +*.gif +*.webp +*.svg +*.woff +*.woff2 +*.ttf +*.eot
-*/wp-json/* -*/feed/* -*utm* -*fbclid* -*ysclid* -*yclid* -*replytocom*
-https://www.googletagmanager.com/* -https://www.google-analytics.com/* -https://mc.yandex.ru/*
EOF
HT_FILTERS=(); while IFS= read -r l; do [[ -z "$l" ]]||HT_FILTERS+=("$l"); done <<<"$FILTERS"

echo "[INFO] httrack…"
httrack "$START_URL" --path "$WORKDIR" --mirror --depth="$DEPTH" --near \
  --robots=0 --keep-alive --sockets=8 --user-agent "$UA" -v "${HT_FILTERS[@]}"

DOMAIN="$(printf '%s' "$START_URL" | awk -F[/:] '{print $4}')"
ROOT_DIR="$(find "$WORKDIR" -maxdepth 1 -type d -regextype posix-extended -regex ".*/${DOMAIN}(-[0-9]+)?$" | head -n1)"
[ -n "${ROOT_DIR:-}" ] || { echo "[ERR] mirror root not found"; find "$WORKDIR" -maxdepth 2 -type d; exit 1; }
echo "[INFO] root: $ROOT_DIR"

# Синхроним без мусора
echo "[INFO] rsync to GCS…"
gsutil -m rsync -r -d -x "(^|/)hts-cache($|/)|(^|/)web\.htm$|(^|/)index\.txt$" "$ROOT_DIR" "gs://${BUCKET}"

# Чиним Content-Type (если где-то ушёл application/octet-stream)
echo "[INFO] fix content-types…"
gsutil -m setmeta -h "Content-Type:text/css"        "gs://${BUCKET}/**/*.css"  || true
gsutil -m setmeta -h "Content-Type:application/javascript" "gs://${BUCKET}/**/*.js"   || true
gsutil -m setmeta -h "Content-Type:image/svg+xml"    "gs://${BUCKET}/**/*.svg"  || true
gsutil -m setmeta -h "Content-Type:font/woff2"       "gs://${BUCKET}/**/*.woff2"|| true
gsutil -m setmeta -h "Content-Type:font/woff"        "gs://${BUCKET}/**/*.woff" || true
gsutil -m setmeta -h "Content-Type:image/webp"       "gs://${BUCKET}/**/*.webp" || true

echo "[DONE]"


