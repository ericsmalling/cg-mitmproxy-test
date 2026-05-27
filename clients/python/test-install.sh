#!/bin/sh
set -e

# Wait for proxy CA cert (mounted from shared volume)
i=0
until [ -f /certs/mitmproxy-ca.pem ]; do
    i=$((i+1))
    [ $i -ge 30 ] && echo "ERROR: Timed out waiting for CA cert" && exit 1
    sleep 1
done

# Trust the mitmproxy CA — pip uses certifi, not the system bundle
cat /certs/mitmproxy-ca.pem >> "$(python -m certifi)"

# Test pip install through proxy (HTTPS_PROXY and SSL_CERT_FILE set by compose)
pip install --no-cache-dir requests

echo "Python test passed"
