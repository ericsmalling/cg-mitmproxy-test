import os
import base64
import logging
from mitmproxy import http

log = logging.getLogger(__name__)

REDIRECT_MAP = {
    "pypi.org": ("/python", "PYTHON_PULL_TOKEN_USER", "PYTHON_PULL_TOKEN_PASS"),
    "files.pythonhosted.org": ("/python", "PYTHON_PULL_TOKEN_USER", "PYTHON_PULL_TOKEN_PASS"),
    "registry.npmjs.org": ("/javascript", "JAVASCRIPT_PULL_TOKEN_USER", "JAVASCRIPT_PULL_TOKEN_PASS"),
    "repo1.maven.org": ("/java", "JAVA_PULL_TOKEN_USER", "JAVA_PULL_TOKEN_PASS"),
    "central.maven.org": ("/java", "JAVA_PULL_TOKEN_USER", "JAVA_PULL_TOKEN_PASS"),
}

# For requests that already target libraries.cgr.dev, inject auth based on path prefix
PATH_AUTH_MAP = {
    "/python":     ("PYTHON_PULL_TOKEN_USER",      "PYTHON_PULL_TOKEN_PASS"),
    "/javascript": ("JAVASCRIPT_PULL_TOKEN_USER",  "JAVASCRIPT_PULL_TOKEN_PASS"),
    "/java":       ("JAVA_PULL_TOKEN_USER",         "JAVA_PULL_TOKEN_PASS"),
}


def _inject_auth(flow: http.HTTPFlow, user_key: str, pass_key: str) -> None:
    user = os.environ.get(user_key, "")
    password = os.environ.get(pass_key, "")
    if user and password:
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        flow.request.headers["Authorization"] = "Basic " + token


def request(flow: http.HTTPFlow) -> None:
    host = flow.request.pretty_host

    # Already headed to the library repo — just ensure auth is present
    if host == "libraries.cgr.dev":
        for prefix, (user_key, pass_key) in PATH_AUTH_MAP.items():
            if flow.request.path.startswith(prefix):
                _inject_auth(flow, user_key, pass_key)
                break
        return

    entry = REDIRECT_MAP.get(host)
    if entry is None:
        return

    path_prefix, user_key, pass_key = entry
    original_path = flow.request.path

    flow.request.host = "libraries.cgr.dev"
    flow.request.headers["Host"] = "libraries.cgr.dev"

    if original_path.startswith(path_prefix):
        flow.request.path = original_path
    elif host == "pypi.org" and original_path.startswith("/simple"):
        rest = original_path[len("/simple"):]
        flow.request.path = path_prefix + "/simple" + rest
    else:
        flow.request.path = path_prefix + original_path

    flow.request.http_version = "HTTP/1.1"
    _inject_auth(flow, user_key, pass_key)

    log.info(f"Redirect: {host}{original_path} -> libraries.cgr.dev{flow.request.path}")
