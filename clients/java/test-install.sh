#!/bin/sh
set -e

# Wait for proxy CA cert
i=0
until [ -f /certs/mitmproxy-ca.pem ]; do
    i=$((i+1))
    [ $i -ge 30 ] && echo "ERROR: Timed out waiting for CA cert" && exit 1
    sleep 1
done

# Import mitmproxy CA into the JVM default truststore
keytool -importcert -noprompt \
    -alias mitmproxy-ca \
    -keystore "$JAVA_HOME/lib/security/cacerts" \
    -storepass changeit \
    -file /certs/mitmproxy-ca.pem

# Maven doesn't read HTTPS_PROXY env var — extract host and port manually
# HTTPS_PROXY format: http://proxy:8080
PROXY_HOST=$(echo "${HTTPS_PROXY}" | sed 's|http://||' | cut -d: -f1)
PROXY_PORT=$(echo "${HTTPS_PROXY}" | sed 's|http://||' | cut -d: -f2)

mvn dependency:resolve -B \
    -Dhttp.proxyHost="${PROXY_HOST}" \
    -Dhttp.proxyPort="${PROXY_PORT}" \
    -Dhttps.proxyHost="${PROXY_HOST}" \
    -Dhttps.proxyPort="${PROXY_PORT}"

echo "Java test passed"
