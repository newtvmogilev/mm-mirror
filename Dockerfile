# База с gsutil внутри
FROM google/cloud-sdk:slim

RUN apt-get update && apt-get install -y httrack && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

CMD ["/app/run.sh"]
