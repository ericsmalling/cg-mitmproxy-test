#!/bin/sh
set -e

# Wait for proxy CA cert
i=0
until [ -f /certs/mitmproxy-ca.pem ]; do
    i=$((i+1))
    [ $i -ge 30 ] && echo "ERROR: Timed out waiting for CA cert" && exit 1
    sleep 1
done

# Trust the mitmproxy CA in the system bundle (needed for Node.js v22+ where
# NODE_EXTRA_CA_CERTS alone is insufficient; also covers older versions)
cat /certs/mitmproxy-ca.pem >> /etc/ssl/certs/ca-certificates.crt

npm install --prefer-online lodash

echo "Node test passed"
