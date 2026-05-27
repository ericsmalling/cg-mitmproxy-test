#!/bin/sh
set -e

# Redirect all outbound 443/80 traffic to mitmproxy, except mitmproxy's own
# connections (uid 65532 = nonroot) to avoid a loop
iptables -t nat -A OUTPUT -p tcp --dport 443 -m owner ! --uid-owner 65532 -j REDIRECT --to-port 8080
iptables -t nat -A OUTPUT -p tcp --dport 80  -m owner ! --uid-owner 65532 -j REDIRECT --to-port 8080

# Run mitmproxy as nonroot so its upstream connections are excluded above
su -s /bin/sh nonroot -c \
    "mitmdump --mode transparent --set confdir=/tmp/mitmproxy -p 8080 -s /app/redirect.py --set block_global=false" &
MITM_PID=$!

until [ -f /tmp/mitmproxy/mitmproxy-ca-cert.pem ]; do sleep 0.5; done
cp /tmp/mitmproxy/mitmproxy-ca-cert.pem /certs/mitmproxy-ca.pem
echo "CA cert exported to /certs/mitmproxy-ca.pem"

wait $MITM_PID
