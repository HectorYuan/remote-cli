#!/usr/bin/env python3
"""
remote-cli enrollment server
一次性 token 注册服务，跑在 Runner 上。
- POST /enroll/key/<token>   新设备提交 SSH 公钥（一次性，写后即焚）
- GET  /enroll/config/<token> 新设备拉取工作站配置（token 不销毁，1h 过期）
- GET  /healthz              健康检查
数据目录: /data (volume 挂载)
"""
import json
import os
import re
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

DATA_DIR = os.environ.get("ENROLL_DATA_DIR", "/data")
TOKEN_TTL = 3600  # 1 小时过期
TOKEN_RE = re.compile(r"^[A-Za-z0-9_-]{16,64}$")
PUBKEY_RE = re.compile(r"^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-\S+|sk-\S+) [A-Za-z0-9+/=]{50,1200}(\s\S+)?\s*$")


def token_path(token: str) -> str:
    return os.path.join(DATA_DIR, f"{token}.json")


def load_token(token: str):
    try:
        with open(token_path(token)) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[{time.strftime('%H:%M:%S')}] {self.address_string()} {fmt % args}", flush=True)

    def _json(self, code: int, payload: dict):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/healthz":
            return self._json(200, {"ok": True})

        m = re.match(r"^/enroll/config/([A-Za-z0-9_-]+)$", self.path)
        if not m:
            return self._json(404, {"error": "not found"})
        token = m.group(1)
        data = load_token(token)
        if not data:
            return self._json(404, {"error": "invalid token"})
        if time.time() > data.get("expires_at", 0):
            os.remove(token_path(token))
            return self._json(410, {"error": "token expired"})
        return self._json(200, {"config": data.get("config", {})})

    def do_POST(self):
        m = re.match(r"^/enroll/key/([A-Za-z0-9_-]+)$", self.path)
        if not m:
            return self._json(404, {"error": "not found"})
        token = m.group(1)
        data = load_token(token)
        if not data:
            return self._json(404, {"error": "invalid token"})
        if time.time() > data.get("expires_at", 0):
            os.remove(token_path(token))
            return self._json(410, {"error": "token expired"})
        if data.get("used"):
            return self._json(409, {"error": "token already used"})

        length = int(self.headers.get("Content-Length", 0))
        if length > 1024:
            return self._json(413, {"error": "body too large"})
        pubkey = self.rfile.read(length).decode("utf-8", "replace").strip()

        if not PUBKEY_RE.match(pubkey):
            return self._json(400, {"error": "invalid public key format"})

        # 保存公钥 + 标记 token 已用（一次性）
        key_file = os.path.join(DATA_DIR, f"{token}.pub")
        with open(key_file, "w") as f:
            f.write(pubkey + "\n")
        data["used"] = True
        data["used_at"] = time.time()
        data["pubkey_file"] = key_file
        with open(token_path(token), "w") as f:
            json.dump(data, f)
        return self._json(200, {"ok": True, "message": "key enrolled"})


if __name__ == "__main__":
    os.makedirs(DATA_DIR, exist_ok=True)
    port = int(os.environ.get("ENROLL_PORT", "8100"))
    server = HTTPServer(("0.0.0.0", port), Handler)
    print(f"enrollment server listening on :{port}", flush=True)
    server.serve_forever()
