# KAAL Spaces — web shell + local service

A browser shell for Spaces, and a small local service that gives it real,
scoped, policy-enforced files. Deliberately not part of the ISO yet: this is a
parallel track while the image build is being moved from lorax to kiwi.

## Run it

```sh
python3 spacesd.py --ui index.html
```

Then open <http://127.0.0.1:8471>. No dependencies, no pip install — Python 3
and a browser. Tested on 3.12 and 3.13 in CI.

On a phone, `index.html` also opens standalone and runs in **local mode**:
same Spaces mechanic, state in `localStorage`, no real files. The badge in the
header says which mode you are in, so the two are never confused.

## What the service does

| endpoint | what it does |
|---|---|
| `GET /` | serves the shell |
| `GET /api/state` | spaces + current policy |
| `GET /api/fs?space=&path=` | lists a directory inside one space |
| `POST /api/write` | writes a file inside one space |
| `POST /api/policy` | grants or revokes a capability for one space |
| `GET /api/audit?limit=` | recent audit events, newest first |

Each space is a directory under `--root` (default `~/kaal-spaces`), with
`policy.json` and an append-only `audit.log` beside them.

## The two rules the code enforces

**Off unless granted.** A write in a space without the `files` grant is refused
with 403, the file is not created, and the refusal is written to the audit log.
A refusal that leaves no trace is indistinguishable from a bug.

**A path cannot leave its space.** Absolute paths and any parent-directory
segment are refused outright; a resolved-path containment check backs that up.
An earlier version silently re-rooted them inside the space, which is contained
but hides caller bugs — an API boundary should refuse a nonsense path, not
quietly reinterpret it.

## Not here yet, on purpose

No AI, no shell execution, no auth, no network egress. Each should arrive with
its policy check already written rather than bolted on afterwards.

## Tests

```sh
python3 test_spacesd.py
```

28 assertions, covering permitted writes, refusals, per-space isolation, path
escape, unknown inputs, and persistence across a restart. Run automatically by
`.github/workflows/spacesd-ci.yml` on Python 3.12 and 3.13.
