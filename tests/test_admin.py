"""End-to-end API checks against disposable Docker containers (no production data).

Run from the repository root: python3 -m unittest discover -s tests -v
Requires Docker Compose and the administration image: docker compose build admin
"""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


class AdminIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="whistor-admin-test-")
        cls.base = Path(cls.temp.name)
        (cls.base / "hs/synapse").mkdir(parents=True)
        (cls.base / "data").mkdir()
        (cls.base / "hs/synapse/hostname").write_text("a" * 56 + ".onion\n")
        cls.project = "whistor-admin-test-" + str(os.getpid())
        with socket.socket() as available_port:
            available_port.bind(("127.0.0.1", 0))
            port = available_port.getsockname()[1]
        config = {
            "services": {
                "synapse": {
                    "image": os.environ.get("TEST_SYNAPSE_IMAGE", "ghcr.io/element-hq/synapse:latest"),
                    "entrypoint": ["/bin/bash", "/entrypoint-custom.sh"],
                    "volumes": [f"{ROOT}/scripts/entrypoint.sh:/entrypoint-custom.sh:ro",
                                f"{ROOT}/config:/config:ro", f"{cls.base}/hs:/tor-hs:ro",
                                f"{cls.base}/data:/data"],
                    "networks": ["internal"],
                },
                "admin": {
                    "image": "whistor-admin:local",
                    "ports": [f"127.0.0.1:{port}:8080"],
                    "networks": ["internal", "access"],
                    "read_only": True,
                    "tmpfs": ["/var/cache/nginx", "/var/run", "/tmp"],
                    "security_opt": ["no-new-privileges:true"],
                },
            },
            "networks": {"internal": {"internal": True}, "access": {}},
        }
        cls.file = cls.base / "compose.json"
        cls.file.write_text(json.dumps(config))
        cls.addClassCleanup(cls.cleanup)
        cls.compose("up", "-d")
        address = cls.compose("port", "admin", "8080").strip()
        cls.url = "http://" + address
        for _ in range(90):
            try:
                cls.request("/_matrix/client/versions")
                break
            except (urllib.error.URLError, ConnectionError):
                time.sleep(1)
        else:
            raise RuntimeError("Synapse did not start: " + cls.compose("logs", "--tail", "30"))
        cls.compose("exec", "-T", "synapse", "register_new_matrix_user", "-c", "/data/homeserver.yaml",
                    "-u", "testadmin", "-p", "Whistor-Test-Password-823!", "-a", "http://localhost:8008")

    @classmethod
    def compose(cls, *args):
        result = subprocess.run(["docker", "compose", "-p", cls.project, "-f", str(cls.file), *args],
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(result.stdout)
        return result.stdout

    @classmethod
    def cleanup(cls):
        cls.compose("down", "--volumes", "--remove-orphans")
        cls.temp.cleanup()

    @classmethod
    def request(cls, path, data=None, token=None, method=None, headers=None):
        headers = dict(headers or {})
        if data is not None:
            headers["Content-Type"] = "application/json"
        if token:
            headers["Authorization"] = "Bearer " + token
        req = urllib.request.Request(cls.url + path, headers=headers, method=method,
                                     data=json.dumps(data).encode() if data is not None else None)
        return urllib.request.urlopen(req, timeout=10)

    def test_management_and_access_modes(self):
        with self.request("/") as response:
            self.assertIn(b"<html", response.read().lower())
        for host, scheme in [("192.168.1.42:8080", "http"),
                             ("server.example-tail.ts.net", "https"),
                             ("localhost:18080", "http")]:
            with self.request("/config.json", headers={"Host": host, "X-Forwarded-Proto": scheme}) as response:
                self.assertEqual(json.load(response), {"restrictBaseUrl": [f"{scheme}://{host}"],
                                                       "wellKnownDiscovery": False})
        with self.assertRaises(urllib.error.HTTPError) as error:
            self.request("/_synapse/admin/v2/users")
        self.assertEqual(error.exception.code, 401)
        with self.request("/_matrix/client/v3/login", {
            "type": "m.login.password", "identifier": {"type": "m.id.user", "user": "testadmin"},
            "password": "Whistor-Test-Password-823!"}) as response:
            login = json.load(response)
        token = login["access_token"]
        user = "@managed:" + "a" * 56 + ".onion"
        path = "/_synapse/admin/v2/users/" + user
        with self.request(path, {"password": "Managed-Test-Password-923!", "displayname": "Managed user",
                                 "admin": False}, token, "PUT") as response:
            self.assertEqual(json.load(response)["name"], user)
        with self.request("/_synapse/admin/v2/users?name=managed", token=token) as response:
            self.assertEqual(json.load(response)["users"][0]["name"], user)
        with self.request(path, {"password": "Changed-Test-Password-425!", "displayname": "Updated user"},
                          token, "PUT") as response:
            self.assertEqual(json.load(response)["displayname"], "Updated user")
        with self.request("/_matrix/client/v3/login", {
            "type": "m.login.password", "identifier": {"type": "m.id.user", "user": "managed"},
            "password": "Changed-Test-Password-425!"}) as response:
            regular_token = json.load(response)["access_token"]
        with self.assertRaises(urllib.error.HTTPError) as error:
            self.request("/_synapse/admin/v2/users", token=regular_token)
        self.assertEqual(error.exception.code, 403)
        with self.request(path, {"deactivated": True}, token, "PUT") as response:
            self.assertTrue(json.load(response)["deactivated"])
        with self.request("/_matrix/client/v3/logout", {}, token) as response:
            self.assertEqual(response.status, 200)
        # Restarting the reverse proxy must not lose its upstream configuration.
        self.compose("restart", "admin")
        for attempt in range(30):
            try:
                with self.request("/_matrix/client/versions") as response:
                    self.assertIn("versions", json.load(response))
                break
            except (urllib.error.URLError, ConnectionError):
                if attempt == 29:
                    raise
                time.sleep(1)
