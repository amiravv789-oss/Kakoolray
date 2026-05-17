# .devcontainer/Dockerfile
FROM debian:bookworm-slim

LABEL maintainer="@Kakoolnews" \
      description="VLESS proxy with multi-user management"

COPY install.sh /app/install.sh

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash git curl wget unzip tzdata openssl ca-certificates uuid-runtime jq python3 \
    && rm -rf /var/lib/apt/lists/*

RUN chmod +x /app/install.sh && /app/install.sh

COPY config.json /etc/config.template.json
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY monitor.sh /usr/local/bin/monitor.sh
COPY panel.py /usr/local/bin/panel.py
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/monitor.sh /usr/local/bin/panel.py

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost:443/ || exit 1

CMD ["/usr/local/bin/entrypoint.sh"]
