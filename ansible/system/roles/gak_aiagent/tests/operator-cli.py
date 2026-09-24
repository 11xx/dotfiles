#!/usr/bin/env python3
import contextlib
import datetime as dt
import importlib.machinery
import io
import json
import os
from pathlib import Path
import shlex
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[5]
COMMAND = ROOT / ".local/bin/gak-aiagent"
operator = importlib.machinery.SourceFileLoader("gak_operator", str(COMMAND)).load_module()
TOKEN = "test-token_123"
ORIGIN = "https://t3.example.test"
LINK = ORIGIN + "/pair#token=" + TOKEN


class WebResponse:
    status = 200

    class headers:
        @staticmethod
        def get_content_type():
            return "text/html"

    def __enter__(self):
        return self

    def __exit__(self, *_):
        pass


class OperatorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gak-operator-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.key = self.root / "identity"
        self.key.write_text("fake key")
        fake = self.root / "fake-command"
        fake.write_text('''#!/usr/bin/env python3
import datetime as dt
import json
import os
from pathlib import Path
import shlex
import sys

name = Path(sys.argv[0]).name
with open(os.environ["FAKE_LOG"], "a") as output:
    output.write(json.dumps([name, *sys.argv[1:]]) + "\\n")
if name == "ssh":
    args = shlex.split(sys.argv[-1])
    if os.environ.get("FAKE_SSH_FAIL") == "1":
        print("test-token_123", file=sys.stderr)
        sys.exit(255)
    if args == ["tailscale", "status", "--json"]:
        print(json.dumps({"MagicDNSSuffix": "example.test."}))
    elif args[-2:] == ["aiagent-readiness", "--live"]:
        if os.environ.get("FAKE_READINESS_FAIL") == "1":
            print("test-token_123", file=sys.stderr)
            sys.exit(18)
    elif "pairing" in args:
        if os.environ.get("FAKE_PAIR_FAIL") == "1":
            print("test-token_123", file=sys.stderr)
            sys.exit(19)
        if os.environ.get("FAKE_MALFORMED") == "1":
            print(json.dumps({"credential": "test-token_123", "pairUrl": "wrong", "expiresAt": "bad"}))
        else:
            origin = args[args.index("--base-url") + 1]
            print(json.dumps({"credential": "test-token_123", "pairUrl": origin + "/pair#token=test-token_123", "expiresAt": (dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=5)).isoformat()}))
    elif args[-1] == "restart":
        sys.exit(17)
elif name == "qrencode":
    with open(os.environ["FAKE_QR_STDIN"], "w") as output:
        output.write(sys.stdin.read())
    print("FAKE QR")
''')
        fake.chmod(0o755)
        for name in ("ssh", "qrencode", "xdg-open"):
            (self.root / name).symlink_to(fake)
        environment = {
            "PATH": str(self.root) + os.pathsep + os.environ["PATH"],
            "GAK_AIAGENT_SSH_KEY": str(self.key),
            "GAK_AIAGENT_T3_URL": ORIGIN,
            "FAKE_LOG": str(self.root / "calls"),
            "FAKE_QR_STDIN": str(self.root / "qr-input"),
        }
        patcher = mock.patch.dict(os.environ, environment)
        patcher.start()
        self.addCleanup(patcher.stop)
        web = mock.patch.object(operator.urllib.request, "urlopen", return_value=WebResponse())
        web.start()
        self.addCleanup(web.stop)

    def invoke(self, *args):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            try:
                code = operator.main(list(args))
            except operator.OperatorError as error:
                print(f"gak-aiagent: {error}", file=stderr)
                code = 1
        return code, stdout.getvalue(), stderr.getvalue()

    def calls(self):
        path = self.root / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_nested_commands_and_streaming_exit(self):
        self.assertEqual(self.invoke("open")[0], 2)
        self.assertEqual(self.invoke("pair")[0], 2)
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.invoke("status")[0], 0)
        self.assertEqual(self.invoke("shell")[0], 0)
        self.assertEqual(self.invoke("restart")[0], 17)
        self.assertEqual(self.invoke("update")[0], 0)
        calls = self.calls()
        self.assertIn("-tt", calls[1])
        self.assertIn("-T", calls[0])
        self.assertEqual([shlex.split(call[-1])[-1] for call in calls],
                         ["status", "shell", "restart", "update"])

    def test_pairing_quotes_label_and_feeds_qr_only_by_stdin(self):
        label = "phone'; touch /unwanted; echo '"
        code, output, error = self.invoke("t3", "pair", label)
        self.assertEqual((code, error), (0, ""))
        self.assertIn(LINK, output)
        self.assertIn("FAKE QR", output)
        self.assertEqual((self.root / "qr-input").read_text(), LINK)
        calls = self.calls()
        pair_args = shlex.split(calls[-2][-1])
        self.assertEqual(pair_args[pair_args.index("--label") + 1], label)
        self.assertEqual(pair_args[pair_args.index("--base-dir") + 1], operator.BASE_DIR)
        self.assertEqual(pair_args[pair_args.index("--ttl") + 1], "5m")
        self.assertTrue(all(TOKEN not in json.dumps(call) for call in calls))
        self.assertFalse((self.root / "unwanted").exists())

    def test_malformed_and_remote_failure_withhold_token(self):
        os.environ["FAKE_MALFORMED"] = "1"
        code, output, error = self.invoke("t3", "pair")
        self.assertEqual(code, 1)
        self.assertNotIn(TOKEN, output + error)
        self.assertIn("malformed", error)
        os.environ.pop("FAKE_MALFORMED")
        os.environ["FAKE_SSH_FAIL"] = "1"
        code, output, error = self.invoke("t3", "pair")
        self.assertEqual(code, 1)
        self.assertNotIn(TOKEN, output + error)
        self.assertIn("SSH connection", error)

    def test_unhealthy_server_and_failed_mint_hide_remote_output(self):
        os.environ["FAKE_READINESS_FAIL"] = "1"
        code, output, error = self.invoke("t3", "pair")
        self.assertEqual(code, 1)
        self.assertIn("unhealthy", error)
        self.assertNotIn(TOKEN, output + error)
        os.environ.pop("FAKE_READINESS_FAIL")
        os.environ["FAKE_PAIR_FAIL"] = "1"
        code, output, error = self.invoke("t3", "pair")
        self.assertEqual(code, 1)
        self.assertIn("Gak command failed", error)
        self.assertNotIn(TOKEN, output + error)

    def test_missing_qr_keeps_link(self):
        real_which = operator.shutil.which
        with mock.patch.object(operator.shutil, "which",
                               side_effect=lambda name: None if name == "qrencode" else real_which(name)):
            code, output, error = self.invoke("t3", "pair")
        self.assertEqual(code, 0)
        self.assertIn(LINK, output)
        self.assertIn("QR unavailable", error)
        self.assertFalse((self.root / "qr-input").exists())

    def test_open_uses_origin_without_pairing(self):
        code, output, error = self.invoke("t3", "open")
        self.assertEqual((code, output, error), (0, "", ""))
        self.assertEqual(self.calls()[-1], ["xdg-open", ORIGIN])

    def test_tailnet_discovery_and_unhealthy_origin(self):
        os.environ.pop("GAK_AIAGENT_T3_URL")
        self.assertEqual(operator.origin(), ORIGIN)
        with mock.patch.object(operator.urllib.request, "urlopen", side_effect=OSError("down")):
            code, output, error = self.invoke("t3", "pair")
        self.assertEqual(code, 1)
        self.assertIn("unreachable", error)
        self.assertFalse(any("pairing" in str(call) for call in self.calls()))


if __name__ == "__main__":
    unittest.main()
