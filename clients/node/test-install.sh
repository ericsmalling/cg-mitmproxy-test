#!/bin/sh
set -e

# Wait for proxy CA cert
i=0
until [ -f /certs/mitmproxy-ca.pem ]; do
    i=$((i+1))
    [ $i -ge 30 ] && echo "ERROR: Timed out waiting for CA cert" && exit 1
    sleep 1
done

# NODE_EXTRA_CA_CERTS=/certs/mitmproxy-ca.pem is set by docker compose
# HTTPS_PROXY is set by docker compose
npm install --prefer-online lodash

echo "Node test passed"
