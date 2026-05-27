FROM cgr.dev/smalls.xyz/node:latest-dev
USER root
WORKDIR /app
COPY test-install.sh /app/test-install.sh
RUN chmod +x /app/test-install.sh
ENTRYPOINT ["sh"]
CMD ["/app/test-install.sh"]
