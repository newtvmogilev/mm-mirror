#!/bin/bash
set -u

TARGET="https://www.google.com/amp/s/mogilev.media/"
OUT="/tmp/mirror"

echo "[1/6] Fetch AMP via Google cache"
wget --mirror --convert-links --adjust-extension --page-requisites \
     --no-verbose --timeout=30 --tries=3 --wait=0.3 --limit-rate=500k \
     --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36" \
     --span-hosts --domains=google.com,googleusercontent.com,cdn.ampproject.org,mogilev.media \
     --accept-regex='^https://(www\.)?google\.com/amp/s/mogilev\.media/.*' \
     -P "$OUT" "$TARGET" || true

echo "[2/6] Root index"
mkdir -p "$OUT"
cat > "$OUT/index.html" <<'EOF'
<!doctype html><meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=https://www.google.com/amp/s/mogilev.media/">
<a href="https://www.google.com/amp/s/mogilev.media/">Open mirror</a>
EOF

echo "[3/6] List top files"; find "$OUT" -maxdepth 3 -type f | head -n 20 || true
echo "[4/6] gsutil info"; gsutil version -l || true
echo "[5/6] Sync to bucket"; gsutil -m rsync -r "$OUT" gs://m-media
echo "[6/6] DONE"
