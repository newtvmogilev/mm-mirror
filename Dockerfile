FROM gcr.io/google.com/cloudsdktool/cloud-sdk:slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    httrack ca-certificates bash && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# дефолты (их можно переопределить в Cloud Run Job)
ENV START_URL="https://mogilev.media/" \
    DEPTH="3"

ENTRYPOINT ["/entrypoint.sh"]
