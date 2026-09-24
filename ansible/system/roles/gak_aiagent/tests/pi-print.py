#!/usr/bin/env python3
"""Check Pi print mode with a local OpenAI-compatible fixture provider."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import threading


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        if self.path != "/v1/chat/completions":
            self.send_error(404)
            return
        assert json.loads(body)["model"] == "fixture-model"
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for delta, reason in [({"role": "assistant", "content": "fixture-ok"}, None),
                              ({}, "stop")]:
            event = {
                "id": "chatcmpl-fixture",
                "object": "chat.completion.chunk",
                "created": 1,
                "model": "fixture-model",
                "choices": [{"index": 0, "delta": delta, "finish_reason": reason}],
            }
            self.wfile.write(b"data: " + json.dumps(event).encode() + b"\n\n")
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()

    def log_message(self, *args):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
config = {
    "providers": {
        "fixture": {
            "baseUrl": f"http://127.0.0.1:{server.server_port}/v1",
            "api": "openai-completions",
            "apiKey": "fixture",
            "models": [{"id": "fixture-model"}],
        }
    }
}
path = Path.home() / ".pi/agent/models.json"
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(config))
try:
    result = subprocess.run(
        ["pi", "-p", "--no-session", "--provider", "fixture", "--model",
         "fixture-model", "hello"],
        capture_output=True, text=True, timeout=15,
    )
finally:
    server.shutdown()
print(f"print mode: exit {result.returncode}, response {result.stdout.strip()!r}")
if result.returncode != 0 or result.stdout.strip() != "fixture-ok":
    raise SystemExit(result.stderr or "Pi print mode did not return the fixture response")
