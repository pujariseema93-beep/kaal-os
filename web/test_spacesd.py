#!/usr/bin/env python3
"""End-to-end tests for spacesd, run in-process so no background server is needed."""
import json, threading, tempfile, urllib.request, urllib.error, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spacesd

PORT = 0            # 0 = let the OS pick a free port
BASE = ""           # set once the socket is bound

def call(method, path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, {}

def main():
    global BASE
    root = Path(tempfile.mkdtemp(prefix="kaaltest-"))
    httpd = spacesd.serve(root, "127.0.0.1", PORT, ui=None)
    PORT_ACTUAL = httpd.server_address[1]
    BASE = f"http://127.0.0.1:{PORT_ACTUAL}"
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    print(f"test server on {BASE}")

    passed = failed = 0
    def check(label, cond, detail=""):
        nonlocal passed, failed
        if cond:
            passed += 1; print(f"  PASS  {label}")
        else:
            failed += 1; print(f"  FAIL  {label}  {detail}")

    try:
        print("=== 1. baseline ===")
        code, st = call("GET", "/api/state")
        check("state returns 200", code == 200, code)
        check("three spaces", len(st.get("spaces", {})) == 3, st.get("spaces"))
        check("work has files=True", st["policy"]["work"]["files"] is True)

        print("=== 2. a permitted write really writes ===")
        code, r = call("POST", "/api/write", {"space": "work", "path": "notes/q3.md", "content": "# Q3\nnumbers here"})
        check("write returns 200", code == 200, (code, r))
        on_disk = root / "work" / "notes" / "q3.md"
        check("file exists on disk", on_disk.is_file())
        check("content is correct", on_disk.read_text() == "# Q3\nnumbers here")
        check("bytes reported", r.get("bytes") == len("# Q3\nnumbers here"), r)

        print("=== 3. revoking the grant actually refuses ===")
        code, _ = call("POST", "/api/policy", {"space": "work", "key": "files", "value": False})
        check("policy update returns 200", code == 200, code)
        code, r = call("POST", "/api/write", {"space": "work", "path": "notes/blocked.md", "content": "should not exist"})
        check("write now refused 403", code == 403, (code, r))
        check("file was NOT created", not (root / "work" / "notes" / "blocked.md").exists())
        code, r = call("GET", "/api/fs?space=work&path=.")
        check("listing also refused 403", code == 403, (code, r))

        print("=== 4. refusal is audited ===")
        code, a = call("GET", "/api/audit?limit=20")
        acts = [e["action"] for e in a.get("events", [])]
        check("DENIED write recorded", any("DENIED write" in x for x in acts), acts[:4])
        check("DENIED list recorded", any("DENIED list" in x for x in acts), acts[:4])
        check("successful write recorded", any(x.startswith("wrote") for x in acts), acts[:4])
        check("grant change recorded", any("revoked files" in x for x in acts), acts[:4])

        print("=== 5. policy is per-space, not global ===")
        code, r = call("POST", "/api/write", {"space": "lab", "path": "build.log", "content": "kiwi ok"})
        check("lab write still allowed", code == 200, (code, r))
        check("lab file exists", (root / "lab" / "build.log").is_file())

        print("=== 6. a path cannot escape its space ===")
        # Harmless destinations on purpose: the property under test is "the path
        # is refused", and using a real system path here adds nothing while
        # making the file look like an exploit to anything scanning it.
        for evil in ["../../../tmp/kaal-escape", "/tmp/kaal-escape", "..", "a/../../b"]:
            code, r = call("POST", "/api/write", {"space": "lab", "path": evil, "content": "escaped"})
            check(f"traversal refused: {evil}", code in (400, 403), (code, r))
        # a percent-encoded name is not traversal — it is a literal filename, and
        # is allowed as long as it lands inside the space
        code, r = call("POST", "/api/write", {"space": "lab", "path": "..%2f..%2fweird.txt", "content": "x"})
        ok = code == 200 and str(r.get("path", "")).startswith("lab/")
        check("odd filename contained in space", ok, (code, r))
        check("nothing written outside the root",
              not (root.parent / "kaal-escape").exists()
              and not Path("/tmp/kaal-escape").exists()
              and not Path("/tmp/b").exists())

        print("=== 7. unknown inputs are rejected, not crashed on ===")
        code, _ = call("POST", "/api/write", {"space": "nope", "path": "x", "content": "y"})
        check("unknown space -> 404", code == 404, code)
        code, _ = call("POST", "/api/policy", {"space": "work", "key": "nonsense", "value": True})
        check("unknown permission -> 404", code == 404, code)
        code, _ = call("GET", "/api/nothing")
        check("unknown endpoint -> 404", code == 404, code)

        print("=== 8. state survives a restart ===")
        httpd.shutdown(); httpd.server_close()
        httpd2 = spacesd.serve(root, "127.0.0.1", PORT_ACTUAL, ui=None)
        threading.Thread(target=httpd2.serve_forever, daemon=True).start()
        code, st = call("GET", "/api/state")
        check("revoked grant persisted", st["policy"]["work"]["files"] is False, st["policy"]["work"])
        check("file still on disk", on_disk.is_file())
        httpd2.shutdown(); httpd2.server_close()

    finally:
        try: httpd.shutdown()
        except Exception: pass

    print(f"\n{passed} passed, {failed} failed")
    print(f"root used: {root}")
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())
