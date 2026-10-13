"""Checks the catalog handlers without starting a long-lived server."""

from __future__ import annotations

import threading
import time
import urllib.error
import urllib.request

from main import HOST, PORT, Handler, ThreadingHTTPServer


def _get(path: str) -> tuple[int, str]:
    url = "http://%s:%s%s" % (HOST, PORT, path)
    try:
        with urllib.request.urlopen(url, timeout=2) as resp:
            return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8")


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    time.sleep(0.1)
    try:
        code, body = _get("/health")
        assert code == 200, code
        assert '"ok"' in body, body
        code, body = _get("/products")
        assert code == 200, code
        assert "SKU-100" in body, body
        code, _ = _get("/missing")
        assert code == 404, code
        print("app/test_api.py: ok")
    finally:
        server.shutdown()


if __name__ == "__main__":
    main()
