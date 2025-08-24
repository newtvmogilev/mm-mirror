# Минимальный образ с gsutil
FROM gcr.io/google.com/cloudsdktool/cloud-sdk:slim

# httrack + сертификаты
RUN apt-get update \
 && apt-get install -y --no-install-recommends httrack ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Точка входа
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
