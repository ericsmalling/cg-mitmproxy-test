FROM cgr.dev/smalls.xyz/python:latest-dev
USER root
RUN apk add --no-cache iptables && pip install --no-cache-dir mitmproxy
COPY redirect.py /app/redirect.py
COPY entrypoint.sh /app/entrypoint.sh
COPY entrypoint-transparent.sh /app/entrypoint-transparent.sh
RUN chmod +x /app/entrypoint.sh /app/entrypoint-transparent.sh
ENTRYPOINT ["/app/entrypoint.sh"]
