"""Test the installed Tuwunel binary with a disposable loopback server and DB.

Run on hetzner-matrix as the ordinary operator; no sudo or live credentials.
Production settings are read only to find the binary and library/certificate
paths. Only the disposable server receives requests or test accounts.
"""

import hashlib
import hmac
import json
import os
import re
import secrets
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread

settings = subprocess.check_output(
    ["systemctl", "show", "tuwunel", "-p", "Environment", "--value"], text=True
)
env = os.environ.copy()
for name in ("LD_LIBRARY_PATH", "SSL_CERT_FILE"):
    env[name] = re.search(rf"(?:^| ){name}=([^ ]+)", settings).group(1)
command = subprocess.check_output(
    ["systemctl", "show", "tuwunel", "-p", "ExecStart", "--value"], text=True
)
binary = re.search(r"path=([^ ;]+)", command).group(1)
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
base = f"http://127.0.0.1:{port}"
secret = secrets.token_hex(24)
password = secrets.token_hex(24)


def request(path, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(
        base + path,
        headers=headers,
        data=json.dumps(body).encode() if body is not None else None,
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as res:
            return res.status, json.load(res)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


class PrivatePage(BaseHTTPRequestHandler):
    hits = 0

    def do_GET(self):
        PrivatePage.hits += 1
        body = (
            b"<html><head><title>Private page</title></head><body>Private</body></html>"
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


with tempfile.TemporaryDirectory(prefix="mindroom-preview-check-") as temporary:
    root = Path(temporary)
    config = root / "config.toml"
    process = None
    token = None
    try:
        for enabled in (False, True):
            config.write_text(
                f'''[global]
server_name = "preview-check.invalid"
database_path = "{root / "db"}"
address = ["127.0.0.1"]
port = {port}
allow_federation = false
startup_netburst = false
grant_admin_to_first_user = false
registration_shared_secret = "{secret}"
log = "warn"
rocksdb_cache_capacity_mb = 32.0
'''
                + ('url_preview_domain_explicit_allowlist = ["*"]\n' if enabled else "")
            )
            env["CONDUWUIT_CONFIG"] = str(config)
            with open(root / "server.log", "w") as log:
                process = subprocess.Popen([binary], env=env, stdout=log, stderr=log)
                for attempt in range(100):
                    if process.poll() is not None:
                        raise RuntimeError(
                            "Disposable server exited: "
                            + (root / "server.log")
                            .read_text()[-4000:]
                            .replace(secret, "[redacted]")
                        )
                    try:
                        status, _ = request("/_matrix/client/versions")
                        if status == 200:
                            break
                    except (OSError, urllib.error.URLError):
                        pass
                    time.sleep(0.2)
                else:
                    raise RuntimeError("Disposable server did not become ready")
                if token is None:
                    status, nonce_reply = request("/_synapse/admin/v1/register")
                    assert status == 200, (status, nonce_reply)
                    nonce = nonce_reply["nonce"]
                    mac = hmac.new(
                        secret.encode(),
                        (
                            nonce + "\0preview_check\0" + password + "\0notadmin"
                        ).encode(),
                        hashlib.sha1,
                    ).hexdigest()
                    status, reply = request(
                        "/_synapse/admin/v1/register",
                        {
                            "nonce": nonce,
                            "username": "preview_check",
                            "password": password,
                            "admin": False,
                            "mac": mac,
                        },
                    )
                    assert status == 200, (status, reply.get("error"))
                    token = reply["access_token"]
                public = "https://www.python.org/"
                path = "/_matrix/client/v1/media/preview_url?" + urllib.parse.urlencode(
                    {"url": public}
                )
                status, reply = request(path, token=token)
                if not enabled:
                    assert (
                        status == 403
                        and "not allowed" in reply.get("error", "").lower()
                    ), (status, reply)
                    print(
                        "Default config: public preview refused",
                        status,
                        reply.get("error"),
                        flush=True,
                    )
                else:
                    assert status == 200 and reply.get("og:title"), (status, reply)
                    print(
                        "Enabled config: public preview succeeds",
                        status,
                        reply["og:title"],
                        flush=True,
                    )
                    with ThreadingHTTPServer(("127.0.0.1", 0), PrivatePage) as private:
                        worker = Thread(target=private.serve_forever, daemon=True)
                        worker.start()
                        private_port = private.server_address[1]
                        try:
                            # Prove localhost resolves and serves valid HTML here.
                            with urllib.request.urlopen(
                                f"http://localhost:{private_port}/", timeout=5
                            ) as probe:
                                assert probe.status == 200
                            PrivatePage.hits = 0
                            for host in (
                                "127.0.0.1",
                                "[::ffff:127.0.0.1]",
                                "localhost",
                            ):
                                address = f"http://{host}:{private_port}/"
                                path = (
                                    "/_matrix/client/v1/media/preview_url?"
                                    + urllib.parse.urlencode({"url": address})
                                )
                                status, reply = request(path, token=token)
                                assert status == 400, (address, status, reply)
                                assert PrivatePage.hits == 0, (
                                    "Preview connected to private server"
                                )
                                if host != "localhost":
                                    assert (
                                        "forbidden" in reply.get("error", "").lower()
                                    ), reply
                                print(
                                    "Private destination refused before HTTP connection",
                                    address,
                                    status,
                                    flush=True,
                                )
                        finally:
                            private.shutdown()
                            worker.join()
                process.terminate()
                process.wait(timeout=30)
                process = None
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=30)
