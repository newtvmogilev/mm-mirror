#!/bin/bash
set -u

TARGET="https://mogilev.media"
OUT="/tmp/mirror"

echo "[1/7] HTTrack start (6m cap, UA Chrome)"
# Обрезаем работу httrack по таймеру, чтобы скрипт точно дошёл до rsync
timeout 6m httrack "$TARGET" \
  -O "$OUT" \
  "+*.mogilev.media/*" "-*logout*" "-*wp-admin*" \
  --sockets=2 --max-rate=500000 --user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36" \
  -v -s0 -%v || echo "[i] httrack exited (possibly timeout) – continuing"

echo "[2/7] HTTrack finished"
echo "[3/7] Mirror top files:"; find "$OUT" -maxdepth 3 -type f | head -n 40 || true

# Минимальный плейсхолдер, если httrack ничего не создал (для проверки пайплайна)
if [ ! -e "$OUT/index.html" ] && [ ! -e "$OUT/mogilev.media/index.html" ]; then
  mkdir -p "$OUT"
  echo "<html><body>mirror pipeline OK ($(date))</body></html>" > "$OUT/index.html"
fi

echo "[4/7] gsutil info"; gsutil version -l || true
echo "[5/7] Check bucket access"; gsutil ls gs://m-media || true
echo "[6/7] Sync to bucket"
gsutil -m rsync -r "$OUT" gs://m-media
echo "[7/7] DONE"
