FROM gcr.io/google.com/cloudsdktool/cloud-sdk:slim

# httrack для зеркалирования
RUN apt-get update && apt-get install -y httrack ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# наш запускной скрипт
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# важное: ничего не переопределять в Cloud Run Job (Command/Args оставить пустыми)
ENTRYPOINT ["/entrypoint.sh"]
