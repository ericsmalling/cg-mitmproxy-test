FROM cgr.dev/<YOUR_ORG>/python:latest-dev
USER root
WORKDIR /app
COPY test-install.sh /app/test-install.sh
RUN chmod +x /app/test-install.sh
CMD ["/app/test-install.sh"]
