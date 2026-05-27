# ZScaler / MITM Proxy Simulation for Chainguard Library Repo

A local test environment that simulates how ZScaler intercepts outbound package manager traffic and routes it through a [Chainguard Library repository](https://edu.chainguard.dev/chainguard/libraries/overview/). Uses [mitmproxy](https://mitmproxy.org) as the stand-in for ZScaler.

The proxy intercepts HTTPS requests to public registries (PyPI, npm, Maven Central), rewrites them to `libraries.cgr.dev`, and injects Chainguard pull-token credentials — all transparently, without any package manager configuration on the client side. This matches how ZScaler auth-injection works in practice.

All container images come from `cgr.dev/<YOUR_ORG>/`.

---

## Prerequisites

- Docker with Compose v2
- [`chainctl`](https://edu.chainguard.dev/chainguard/chainctl-docs/) authenticated to the `<YOUR_ORG>` org
- [`cosign`](https://github.com/sigstore/cosign) **≤ 3.0.5** (3.0.6+ breaks `chainctl libraries verify` due to a SLSA v1 predicate type mismatch)

Authenticate Docker for `cgr.dev` image pulls:
```sh
chainctl auth configure-docker
```

---

## Setup

Generate per-ecosystem pull tokens and populate `.env`:

```sh
cp .env.example .env

chainctl auth pull-token create --parent <YOUR_ORG> --repository python      -o json
chainctl auth pull-token create --parent <YOUR_ORG> --repository javascript  -o json
chainctl auth pull-token create --parent <YOUR_ORG> --repository java        -o json
```

Paste the `username` and `password` fields from each into `.env`.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Docker network                                             │
│                                                             │
│  ┌──────────────┐   HTTPS    ┌──────────────────────────┐  │
│  │ test clients │ ─────────▶ │   mitmproxy :8080        │  │
│  │ (pip/npm/mvn)│            │   redirect.py            │  │
│  └──────────────┘            └────────────┬─────────────┘  │
│                                           │ rewrites host   │
└───────────────────────────────────────────┼─────────────────┘
                                            │ injects Basic auth
                                            ▼
                              ┌─────────────────────────────┐
                              │  libraries.cgr.dev          │
                              │  (Chainguard Library Repo)  │
                              └─────────────────────────────┘
```

Registry redirect map in `proxy/redirect.py`:

| Client requests | Proxy rewrites to |
|---|---|
| `pypi.org` | `libraries.cgr.dev/python/simple/...` |
| `files.pythonhosted.org` | `libraries.cgr.dev/python/...` |
| `registry.npmjs.org` | `libraries.cgr.dev/javascript/...` |
| `repo1.maven.org` | `libraries.cgr.dev/java/...` |
| `central.maven.org` | `libraries.cgr.dev/java/...` |

---

## Running

### Explicit proxy mode (Phase 1)

Clients have `HTTPS_PROXY=http://proxy:8080` set via Docker Compose environment. Simpler to set up; useful for testing the redirect and auth-injection logic.

```sh
# Start the proxy
docker compose up -d

# Run a test client (node shown; python-client and java-client also available)
./test-node.sh

# Watch proxy traffic in real time
docker compose logs -f proxy

# Visual flow inspector
open http://localhost:8081
```

### Transparent proxy mode (Phase 2)

Uses `docker-compose.transparent.yml`. Clients have **no** proxy configuration at all — they share the proxy container's network namespace (`network_mode: service:proxy`) and iptables OUTPUT rules intercept their outbound port 443/80 traffic. Matches real ZScaler behaviour.

```sh
# Start the transparent proxy (separate compose file)
docker compose -f docker-compose.transparent.yml up -d

# Run the node test (passes --transparent so test-node.sh selects the right compose file)
./test-node.sh --transparent

# Watch proxy traffic
docker compose -f docker-compose.transparent.yml logs -f proxy

# Tear down
docker compose -f docker-compose.transparent.yml down
```

### `test-node.sh` does:
1. Checks cosign ≤ 3.0.5 (hard-fails if newer)
2. Clears `cache/npm` so results reflect only the current run
3. `docker compose run node-client` — installs `lodash` via the proxy
4. `chainctl libraries verify --detailed cache/npm` — verifies packages are Chainguard-built via SLSA attestation

---

## Verified behaviour

- `registry.npmjs.org` traffic intercepted and rewritten to `libraries.cgr.dev/javascript/`
- CDN tarball fetches (302-redirected to `172.64.66.1/prod-serve-js/...`) also receive auth injection via `PATH_AUTH_MAP`
- `lodash@4.18.1` (Chainguard-rebuilt, not present on upstream npm as of the time of testing) shows as **100% Verified as built from source** via SLSA attestation

---

## Files

```
proxy/
  Dockerfile                  cgr.dev/<YOUR_ORG>/python:latest-dev + iptables + mitmproxy
  redirect.py                 mitmproxy addon — host rewrite, path prefix, Basic auth injection
  entrypoint.sh               explicit proxy startup
  entrypoint-transparent.sh   iptables OUTPUT rules + mitmproxy in transparent mode as nonroot

clients/
  python/   cgr.dev/<YOUR_ORG>/python:latest-dev — pip install test
  node/     cgr.dev/<YOUR_ORG>/node:latest-dev   — npm install test + chainctl verify
  java/     cgr.dev/<YOUR_ORG>/maven:latest       — mvn dependency:resolve test

docker-compose.yml              explicit proxy (HTTPS_PROXY env var)
docker-compose.transparent.yml  transparent proxy (iptables, network_mode: service:proxy)
test-node.sh                    end-to-end test script for npm path
```

---

## Known issues / incomplete

- **cosign 3.0.6 compatibility**: `chainctl libraries verify` fails with `invalid predicate type, expected custom got https://slsa.dev/provenance/v1` on cosign ≥ 3.0.6. Pin to 3.0.5 until Chainguard updates `chainctl` to accept SLSA v1 provenance predicates. Tracked by the test's version gate.

- **Python and Java clients untested**: `clients/python/` and `clients/java/` were built but only `node-client` has been exercised and verified end-to-end. `test-node.sh` should be duplicated into `test-python.sh` and `test-java.sh` with equivalent `chainctl libraries verify` steps for those ecosystems (`cache/pip` and `cache/maven` bind mounts not yet added to the compose files).

- **Maven library URL unconfirmed**: `libraries.cgr.dev/java/` is inferred from the Python/JavaScript naming pattern. Needs verification against actual Maven pull token output before `java-client` is tested.

- **Pull token expiry**: Tokens have a TTL (default ~30 days). The `.env` will silently stop working when they expire. Consider scripting token rotation or using a service account with a longer-lived identity.

- **Transparent proxy on macOS Docker Desktop / OrbStack**: The `NET_ADMIN` + iptables approach works inside Linux containers, but host-level network interception (without Docker) would require a different mechanism on macOS.

- **No TLS pinning bypass**: Some package managers (newer pip, npm with `--strict-ssl`) may reject the mitmproxy CA if they use certificate pinning or out-of-band trust stores not covered by `SSL_CERT_FILE` / `NODE_EXTRA_CA_CERTS`. Needs testing with stricter client configs.

- **Transparent proxy for Python/Java clients not wired up**: `docker-compose.transparent.yml` currently only has `node-client`. Python and Java need to be added once their explicit-mode tests pass.
