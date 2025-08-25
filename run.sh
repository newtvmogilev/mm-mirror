#!/bin/bash
set -e

TARGET="https://mogilev.media"
OUT="/tmp/mirror"

# Качаем сайт (по умолчанию соблюдает robots.txt)
httrack "$TARGET" \
  -O "$OUT" \
  "+*.mogilev.media/*" \
  "-*logout*" "-*wp-admin*" \
  -v -s0 -%v

# Заливаем в ваш бакет
gsutil -m rsync -r "$OUT" "gs://m-media"
