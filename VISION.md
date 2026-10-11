# KAAL OS — Vision and Architecture

> **Status: design intent, not implementation.** Sections 3 to 6 describe what KAAL
> OS is being designed to be. None of it exists in code today. Section 8 states the
> honest current state, and section 6 states plainly what the privacy design does
> *not* protect against.

---

## 1. What KAAL OS is

KAAL OS is a Fedora-based operating system built around one idea: **an OS you can
shape.** Rather than shipping a fixed set of editions and asking you to pick one,
KAAL OS treats its own configuration as the product — so the system can be
reconfigured into whatever a given situation needs.

On top of that foundation, KAAL OS aims to become an OS with an **AI control
plane**: one that can run a local model or call a cloud AI *under restriction*,
drive a task autonomously through to completion while making system- and
app-level changes, and watch what happens with an antivirus and AI-heuristic
detection layer — all designed so that personal and private data is not exposed.

### Where it actually is today

Honesty matters more than momentum here, so this is the real state:

- **Built:** a Fedora 44 base, a live-ISO build pipeline, a config-driven
  "spaces" engine, generated systemd targets, Btrfs/snapper snapshot support, a
  Calamares installer path, and audit rules in `kaal-security`.
- **In progress:** the live image builds, and it boots under UEFI to a text
  login. Console login and the graphical desktop are still being fixed.
- **Not built yet:** the entire AI control plane, the autonomous task executor,
  and the detection layer. They are design intent — described below, not
  delivered.

Nothing in sections 3 to 6 exists in code today.

---

## 2. The core idea: an OS you shape

KAAL OS is organised around **spaces**. A space is a named configuration of the
whole system — which services run, which targets are active, what the session
looks like, what the machine is *for*.

The four profiles you may have seen (gaming, development, power, normal) were
only startup test templates. The real goal is **moldability**: an OS that a user
can shape to any situation, with the architecture staying config-driven so that
shaping it is a matter of changing configuration, not rewriting the system.

Spaces already exist in the tree as configuration, with generated systemd
targets. Everything in this document is designed to sit on that engine rather
than beside it.

---

## 3. The AI control plane

KAAL OS is designed to have two ways to run AI, and to let you choose which
applies where.

**Local AI.** A model that runs on the machine. It has no network egress at all —
by construction, not by policy. This is the only privacy posture that can be
guaranteed, because there is nothing to intercept.

**Cloud AI, under restriction.** An external API, used only within rules you
define. Because data leaves the machine, this mode cannot be guaranteed — it is
*controlled*.

### The rule model

Rules are **user-defined**, and they apply at three levels:

- **Per system** — a baseline for the whole machine.
- **Per app** — each application carries its own allow/deny policy.
- **Per file** — individual files or paths can be classified separately.

The three levels compose: a file-level rule overrides an app-level rule, which
overrides the system baseline. A user can therefore say, for example, that one
directory may never be sent anywhere, that a specific app may use cloud AI only
for text it generates itself, and that everything else stays local by default.

### One place for the grant

All of it lives in one place: a single settings surface where the user declares
what the AI may access, at system, app and file level. Centralising this is not
cosmetic. A permission model is only as good as the user's ability to see and
change the whole grant in one view — scattered settings produce accidental
permissions, and accidental permissions are the ones that get exploited. One
place also means one place to review, one place to audit, and one place a
designer can shape.

### What "restricted" means mechanically

Restriction is not a setting, it is an enforcement path. Before anything is sent
to a cloud service, it passes through:

1. **Classification** — what kind of data is this, and which rules apply?
2. **Redaction** — strip or mask what the rules forbid leaving.
3. **Egress control** — refuse the request outright if the rules say so.
4. **Audit** — record what was sent, to whom, under which rule.

This is a data-flow control problem, and it is the hard part of the whole
vision. It is also the part where the design has to be honest: see section 6.

---

## 4. Autonomous task control

**Complete Autonomous Task Control to Done** is the goal: you give KAAL OS a
task, and it drives that task through to completion — including making
system-level and app-level changes — without you babysitting it.

**The AI holds exactly the authority the user grants it — no more.** That is the
design's central promise, and it is why the capability model comes before any
question of what the AI may do. Autonomy in KAAL OS is designed around three
things:

### Per-space autonomy rules

There is no single global answer to "may the AI act on its own?". **Each space
sets its own rule.** A locked-down space may require confirmation before every
change; a space built for unattended work may act freely; a space for a shared
machine may forbid system-level changes entirely. Because spaces are
configuration, this is a property of the environment the user chose, not a
global switch they have to remember.

### Snapshot before change, roll back on failure

No autonomous change is made without a recovery point. KAAL OS already carries
Btrfs and snapper support; the executor is designed to take a snapshot before
acting and roll back automatically if the change fails or does not verify. This
is what makes autonomy survivable — not caution, but the ability to undo.

### Capability model and audit

The agent operates against a defined set of capabilities: what it may touch,
what it may not, and what requires an explicit grant. Every action it takes is
recorded, so a change can always be traced back to the task that caused it.

### Where a permission model is not enough

"The AI gets only what the user allows" is true by design, and it is the right
foundation. On its own it is not sufficient, and saying so is part of keeping
this document honest:

- **Borrowed authority, not escalated authority.** The AI reads things — files,
  pages, messages, output from other programs. Some of that content will carry
  instructions aimed at the AI itself. An attacker who plants such content does
  not need more permission; they need the AI's *existing* permission pointed
  somewhere else. This is the central risk in any agentic system, and no
  permission model alone closes it.
- **Composition.** Two allowed actions can each be harmless and still be
  dangerous together. Reading a private file is allowed; reaching the network is
  allowed. The risk lives only in the pairing, which no single rule describes.
- **Enforcement is code.** A grant is only as precise as the code that checks
  it, and only as trustworthy as the tests behind that code.

The practical consequence for the design: permissions have to be expressed not
only as *what the AI may touch*, but as *what it may do with what it has already
read* — and untrusted input must never be able to raise the AI's own authority.

### Provenance, not truth

A tempting answer to borrowed authority is to have the detection layer tell the
AI what is true. It does not work, and the reasons are worth writing down before
someone builds it:

- **Truth is not a property a model can certify.** A model can classify where
  text came from, and whether it reads like instructions aimed at an AI. It
  cannot decide whether a claim is correct. An oracle that sounds authoritative
  and is sometimes wrong is worse than no oracle at all: it launders falsehood
  into trusted input, which is the exact failure it was meant to prevent.
- **The oracle can be steered the same way.** If the guard model reads the same
  untrusted content, that content can steer it too. Moving the check does not
  remove the exposure.
- **Whatever becomes the final authority becomes the thing worth compromising.**
  If the detection layer decides what the AI may believe, then compromising the
  detection layer compromises everything standing behind it.

What an OS can do — and what an application cannot — is supply *verifiable*
facts instead of judgements: where a file came from, whether it has been modified
since it was signed, which process produced it, whether its source is one the
user has marked as trusted. Provenance and integrity are checkable. Truth is not.

So the rule is not "ask whether this is true". It is **"ask where this came from,
and can that be verified"** — with anything unverifiable treated as untrusted, no
matter how plausible it reads.

---

## 5. Detection: AV and AI-heuristic AV

KAAL OS is designed to carry a detection layer that watches for malicious
behaviour — a conventional antivirus component, and an **AI-heuristic**
component for patterns that no signature covers.

The AI-heuristic part matters because autonomous change produces novel system
behaviour by design, and signature-based detection is blind to anything it has
not seen.

Its limits are real and should be stated up front:

- **It is probabilistic.** Heuristics produce false positives and false
  negatives. It is a detection aid, not a proof of safety.
- **The self-change problem.** KAAL OS's own AI legitimately changes the system.
  A detection layer that cannot distinguish that from an intrusion will either
  cry wolf constantly or be switched off. Separating "authorised change" from
  "suspicious change" is a design requirement, not a detail.

---

## 6. Privacy: the design goal, the mechanism, and what it does not cover

### The design goal

KAAL OS is designed so that personal and private data is not exposed by the AI
features — including when a cloud AI is used, and including when the system is
making changes on its own.

### The mechanism

- **Local AI is the default posture** for anything sensitive: no egress, nothing
  to intercept.
- **Cloud AI is permitted only inside rules the user writes**, enforced through
  classification, redaction, egress control and audit (section 3).
- **Autonomous changes are snapshotted and audited** (section 4), so both the
  action and its data access are traceable.

### What this does NOT protect against

This section exists because a claim of "no leak" cannot be honestly made by any
design, and KAAL OS should not be described as if it could:

- **Borrowed authority.** Content the AI reads can carry instructions aimed at
  it. If that content reaches an AI holding file or network permissions, those
  permissions can be turned against the user without any rule being broken. The
  rules were followed; the intent was not.
- **A compromised application with legitimate credentials.** If an app is
  allowed to reach the network and is itself malicious, rules cannot tell.
- **Side channels and inference.** Data can be inferred from metadata, timing,
  or repeated queries, without the content ever being sent.
- **Model memorisation and provider retention.** A cloud provider may retain
  what it receives, and a model may reproduce training data. Neither is under
  KAAL OS's control.
- **Misconfiguration.** A permissive rule is a permissive rule. The model is
  only as strong as what the user wrote.
- **Anything with physical or privileged access** to the machine.
- **The local model's own weaknesses** — it cannot leak over a network, but it
  can still be manipulated into producing harmful output.

Stated plainly: local AI gives a guarantee; cloud AI gives control. KAAL OS
should always be described that way.

---

## 7. Architecture: how the pieces fit

```
  user task / intent
        |
        v
  [ spaces engine ]  --- configuration: what this machine is for
        |
        v
  [ AI control plane ]
        |  chooses: local model  |  cloud API (policy-gated)
        v
  [ policy store ]  system rules · app rules · file rules
        |
        v
  [ task executor ] --- capabilities, approval gates per space
        |                    |
        |                    +--> [ snapshot / rollback ]  (Btrfs + snapper)
        v
  [ audit log ]  <--- every action and every egress event
        ^
        |
  [ detection layer ]  AV + AI heuristics
```

Every layer sits on components the project already has or already plans: spaces
as configuration, systemd targets as the enforcement surface, Btrfs and snapper
for recovery, and the existing audit rules for the trail.

---

## 8. Current state and roadmap

**Built:** Fedora 44 base · live-ISO build pipeline · spaces engine with
generated targets · Btrfs/snapper snapshot support · Calamares installer path ·
`kaal-security` audit rules.

**In progress:** live image builds and boots under UEFI to a text login; console
login and the graphical desktop are being fixed.

**Not started:** AI control plane · policy store · task executor · detection
layer.

A sensible order, once the image is sound:

1. Finish boot and desktop.
2. Make spaces genuinely user-authorable (documented schema, CLI, validation,
   rollback).
3. Build the policy store and the audit log first — the parts that constrain,
   before the parts that act.
4. Add the local-model backend. Local first, because it is the provable case.
5. Add cloud backends behind the policy gate.
6. Add the task executor with snapshots and per-space approval rules.
7. Add the detection layer last, once there is real behaviour to observe.

---

## 9. Who this is for, and how to help

KAAL OS is looking for **testers** and **UI/UX co-designers**.

The honest framing of the working relationship is: **the designer directs the
AI.** The architecture is config-driven, so design decisions translate into
configuration rather than into a rewrite — which is what makes co-design
practical at this stage.

If you are a tester: the useful thing is a machine that can boot the live image
and report what actually happens. If you are a designer: the useful thing is to
shape what a space should feel like, and what the AI control plane should ask
you before it acts.

Both are wanted. Neither requires writing kernel code.
