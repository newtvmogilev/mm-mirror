# База с предустановленным gsutil (нужно для заливки в GCS)
FROM gcr.io/google.com/cloudsdktool/cloud-sdk:slim

# Устанавливаем httrack; чистим кеши, чтобы образ был меньше
RUN apt-get update \
 && apt-get install -y --no-install-recommends httrack ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Рабочая директория (скрипт пишет временные файлы в /work)
WORKDIR /app
RUN mkdir -p /work

# Кладём наш запускной скрипт
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Важно: команду/аргументы в Cloud Run Job ОСТАВИТЬ ПУСТЫМИ,
# чтобы отработал именно этот ENTRYPOINT.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
