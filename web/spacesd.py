#!/usr/bin/env python3
"""
spacesd — the smallest honest backend for KAAL Spaces.

Why this exists
---------------
The browser probe showed that Spaces work as a *mechanic*: separate state per
space, a policy store, an audit log. But it was simulated — localStorage and
nothing else. The open question is whether a web shell plus a small local
service can do real work: real files on a real filesystem, scoped per space,
with policy actually enforced rather than merely displayed.

This daemon answers that question in the smallest possible form. It is:

  * stdlib only — no pip install, runs on any Python 3.9+ (Mint, Ubuntu,
    Windows, macOS, a Raspberry Pi),
  * local only — binds 127.0.0.1 by default, so nothing is exposed,
  * scoped — each space is a directory; paths cannot escape their space,
  * policy-enforcing — a write in a space without the `files` grant is refused
    with 403 and *recorded*, which is the part that matters,
  * auditable — every action appends a JSON line to audit.log.

Deliberately NOT here: no AI, no shell execution, no network egress, no auth.
Those are the next increments, and each should arrive with its policy check
already written rather than bolted on afterwards.

Usage
-----
    python3 spacesd.py                 # http://127.0.0.1:8471
    python3 spacesd.py --port 9000 --root ~/kaal-spaces
"""

from __future__ import annotations

import argparse
import json
import os
import posixpath
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

SPACES = {
    "work":     {"name": "Work",     "accent": "#b9f2d0"},
    "personal": {"name": "Personal", "accent": "#dceeff"},
    "lab":      {"name": "Lab",      "accent": "#e8e1ff"},
}

# Default policy per space. Off unless granted — the vision document's rule.
DEFAULT_POLICY = {
    "work":     {"files": True,  "network": False, "ai": False, "shell": False},
    "personal": {"files": True,  "network": True,  "ai": False, "shell": False},
    "lab":      {"files": True,  "network": True,  "ai": True,  "shell": False},
}

MAX_BODY = 1 << 20          # 1 MiB is plenty for a note
MAX_READ = 256 * 1024       # refuse to slurp huge files into a JSON response


class Store:
    """Filesystem + policy + audit, with no HTTP in it, so it can be tested."""

    def __init__(self, root: Path):
        self.root = root
        self.root.mkdir(parents=True, exist_ok=True)
        self.policy_path = self.root / "policy.json"
        self.audit_path = self.root / "audit.log"
        self._lock = threading.Lock()
        for key in SPACES:
            (self.root / key).mkdir(exist_ok=True)
        if not self.policy_path.exists():
            self._write_policy(DEFAULT_POLICY)

    # ---- policy ----------------------------------------------------------
    def _read_policy(self) -> dict:
        try:
            return json.loads(self.policy_path.read_text())
        except Exception:
            return json.loads(json.dumps(DEFAULT_POLICY))

    def _write_policy(self, policy: dict) -> None:
        self.policy_path.write_text(json.dumps(policy, indent=2) + "\n")

    def policy(self) -> dict:
        return self._read_policy()

    def set_policy(self, space: str, key: str, value: bool) -> dict:
        self._require_space(space)
        if key not in DEFAULT_POLICY[space]:
            raise KeyError(key)
        with self._lock:
            pol = self._read_policy()
            pol[space][key] = bool(value)
            self._write_policy(pol)
        self.audit(space, f"{'granted' if value else 'revoked'} {key}")
        return pol

    # ---- audit -----------------------------------------------------------
    def audit(self, space: str, action: str) -> None:
        line = json.dumps({"t": time.strftime("%Y-%m-%dT%H:%M:%S"), "space": space, "action": action})
        with self._lock:
            with self.audit_path.open("a") as fh:
                fh.write(line + "\n")

    def audit_tail(self, limit: int = 50) -> list:
        if not self.audit_path.exists():
            return []
        lines = self.audit_path.read_text().splitlines()[-limit:]
        out = []
        for ln in lines:
            try:
                out.append(json.loads(ln))
            except Exception:
                pass
        return list(reversed(out))

    # ---- files -----------------------------------------------------------
    def _require_space(self, space: str) -> None:
        if space not in SPACES:
            raise KeyError(space)

    def _space_root(self, space: str) -> Path:
        self._require_space(space)
        return self.root / space

    def _resolve(self, space: str, rel: str) -> Path:
        """Resolve a space-relative path, refusing anything that escapes it.

        Two layers, deliberately:

        1. Explicit rejection of absolute paths and of any parent-directory
           segment. An earlier version silently re-rooted them inside the space,
           which is *contained* but hides caller bugs. An API boundary should
           refuse a nonsense path, not quietly reinterpret it.
        2. A resolved-path containment check as the backstop, in case a future
           change to the normalisation reintroduces an escape.
        """
        base = self._space_root(space).resolve()
        rel = (rel or ".").strip().replace("\\", "/")

        if rel.startswith("/") or (len(rel) > 1 and rel[1] == ":"):
            raise PermissionError("absolute paths are not allowed")
        if any(seg == ".." for seg in rel.split("/")):
            raise PermissionError("path escapes space")

        target = (base / rel).resolve()
        if base != target and base not in target.parents:
            raise PermissionError("path escapes space")
        return target

    def listing(self, space: str, rel: str = ".") -> list:
        target = self._resolve(space, rel)
        if not target.exists():
            return []
        if target.is_file():
            return [{"name": target.name, "dir": False, "size": target.stat().st_size}]
        items = []
        for p in sorted(target.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
            try:
                items.append({
                    "name": p.name,
                    "dir": p.is_dir(),
                    "size": 0 if p.is_dir() else p.stat().st_size,
                })
            except OSError:
                continue
        return items

    def read(self, space: str, rel: str) -> str:
        target = self._resolve(space, rel)
        if not target.is_file():
            raise FileNotFoundError(rel)
        if target.stat().st_size > MAX_READ:
            raise ValueError("file too large to read here")
        return target.read_text(errors="replace")

    def write(self, space: str, rel: str, content: str) -> dict:
        # THE point of this file: policy is checked before anything is written,
        # and a refusal is audited rather than silently ignored.
        if not self.policy()[space].get("files"):
            self.audit(space, f"DENIED write {rel} (no files grant)")
            raise PermissionError("files not granted in this space")
        target = self._resolve(space, rel)
        if target.is_dir():
            raise IsADirectoryError(rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        self.audit(space, f"wrote {rel} ({len(content)} bytes)")
        return {"path": str(target.relative_to(self.root)), "bytes": len(content)}


class Handler(BaseHTTPRequestHandler):
    server_version = "spacesd/0.1"
    store: Store = None          # set by serve()
    ui_path: Path = None         # optional single-file UI to serve at /

    def log_message(self, fmt, *args):    # quieter than the default
        pass

    # ---- helpers ---------------------------------------------------------
    def _json(self, code: int, payload) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _err(self, code: int, msg: str) -> None:
        self._json(code, {"error": msg})

    def _body(self) -> dict:
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0 or n > MAX_BODY:
            return {}
        try:
            return json.loads(self.rfile.read(n).decode())
        except Exception:
            return {}

    # ---- routes ----------------------------------------------------------
    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)

        if u.path in ("/", "/index.html"):
            if self.ui_path and self.ui_path.exists():
                data = self.ui_path.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            else:
                self._err(404, "no UI configured — pass --ui path/to/probe.html")
            return

        if u.path == "/api/state":
            self._json(200, {"spaces": SPACES, "policy": self.store.policy()})
            return

        if u.path == "/api/audit":
            try:
                limit = max(1, min(200, int(q.get("limit", ["50"])[0])))
            except ValueError:
                limit = 50
            self._json(200, {"events": self.store.audit_tail(limit)})
            return

        if u.path == "/api/fs":
            space = q.get("space", [""])[0]
            rel = q.get("path", ["."])[0]
            try:
                if not self.store.policy()[space].get("files"):
                    self.store.audit(space, f"DENIED list {rel} (no files grant)")
                    self._err(403, "files not granted in this space")
                    return
                self._json(200, {"space": space, "path": rel, "items": self.store.listing(space, rel)})
            except KeyError:
                self._err(404, "unknown space")
            except PermissionError as e:
                self._err(403, str(e))
            except Exception as e:
                self._err(400, str(e))
            return

        self._err(404, "no such endpoint")

    def do_POST(self):
        u = urlparse(self.path)
        body = self._body()

        if u.path == "/api/write":
            space = body.get("space", "")
            rel = body.get("path", "")
            content = body.get("content", "")
            try:
                result = self.store.write(space, rel, content)
                self._json(200, {"ok": True, **result})
            except KeyError:
                self._err(404, "unknown space")
            except PermissionError as e:
                self._err(403, str(e))
            except Exception as e:
                self._err(400, str(e))
            return

        if u.path == "/api/policy":
            space = body.get("space", "")
            key = body.get("key", "")
            value = bool(body.get("value"))
            try:
                pol = self.store.set_policy(space, key, value)
                self._json(200, {"ok": True, "policy": pol})
            except KeyError as e:
                self._err(404, f"unknown space or permission: {e}")
            except Exception as e:
                self._err(400, str(e))
            return

        self._err(404, "no such endpoint")


def serve(root: Path, host: str, port: int, ui: Path | None):
    Handler.store = Store(root)
    Handler.ui_path = ui
    httpd = ThreadingHTTPServer((host, port), Handler)
    return httpd


def main() -> None:
    ap = argparse.ArgumentParser(description="KAAL Spaces local service")
    ap.add_argument("--root", default=str(Path.home() / "kaal-spaces"),
                    help="where space directories, policy.json and audit.log live")
    ap.add_argument("--host", default="127.0.0.1", help="bind address (loopback by default)")
    ap.add_argument("--port", type=int, default=8471)
    ap.add_argument("--ui", default=None, help="single-file HTML UI to serve at /")
    args = ap.parse_args()

    root = Path(os.path.expanduser(args.root)).resolve()
    ui = Path(args.ui).resolve() if args.ui else None
    httpd = serve(root, args.host, args.port, ui)

    print(f"spacesd listening on http://{args.host}:{args.port}")
    print(f"  root   : {root}")
    print(f"  spaces : {', '.join(SPACES)}")
    print(f"  audit  : {root / 'audit.log'}")
    if ui:
        print(f"  ui     : {ui}")
    else:
        print("  ui     : none — pass --ui to serve a page at /")
    print("Ctrl-C to stop.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nstopping")
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
