FROM cgr.dev/<YOUR_ORG>/maven:latest
USER root
WORKDIR /app
COPY pom.xml /app/pom.xml
COPY test-install.sh /app/test-install.sh
RUN chmod +x /app/test-install.sh
CMD ["/app/test-install.sh"]
