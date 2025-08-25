#!/bin/bash
set -euo pipefail

BUCKET="${BUCKET:?set BUCKET env}"
TARGET="${TARGET:-https://mogilev.media/}"
OUT="/tmp/mirror"
rm -rf "$OUT"; mkdir -p "$OUT"

# Подключаем WARP мягко (если уже подключён — не упадём)
warp-cli --accept-tos register || true
warp-cli set-mode warp || true
warp-cli connect || true
warp-cli status || true

# Зеркалим
httrack "$TARGET" -O "$OUT" "+*.mogilev.media/*" "-*logout*" "-*wp-admin*" \
  --sockets=6 --max-rate=1500000 -s0 -%v -v \
  --user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36" \
  || echo "[mirror] httrack non-zero -> continue"

# Синхронизируем в GCS
gsutil -m rsync -r "$OUT" "gs://${BUCKET}"
echo "[mirror] DONE"
