FROM gcr.io/google.com/cloudsdktool/cloud-sdk:slim
RUN apt-get update && apt-get install -y httrack ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
