FROM cgr.dev/<YOUR_ORG>/node:latest-dev
USER root
WORKDIR /app
COPY test-install.sh /app/test-install.sh
RUN chmod +x /app/test-install.sh
ENTRYPOINT ["sh"]
CMD ["/app/test-install.sh"]
