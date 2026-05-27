#!/bin/sh
set -e

mitmdump -p 8080 -s /app/redirect.py --set block_global=false &
MITM_PID=$!

until [ -f /root/.mitmproxy/mitmproxy-ca-cert.pem ]; do
    sleep 0.5
done
cp /root/.mitmproxy/mitmproxy-ca-cert.pem /certs/mitmproxy-ca.pem
echo "CA cert exported to /certs/mitmproxy-ca.pem"

wait $MITM_PID
