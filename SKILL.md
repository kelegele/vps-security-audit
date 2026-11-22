---
name: vps-security-audit
description: Read-only security audit for Linux servers (Debian/Ubuntu first). Detects intrusions, backdoors, crypto miners, suspicious logins, rogue cron jobs, hidden SSH keys, rootkit traces via 12 evidence checks. Use when the user asks to check server security, audit a VPS, react to a hosting-provider security alert, or says things like 安检服务器 / 检查服务器 / server audit / security check / "was I hacked" / "check for miners".
---

# VPS Security Audit

Collect read-only evidence from a Linux server, then judge it against a
built-in interpretation table. Produces a graded report (OK / SUSPICIOUS /
CRITICAL). **Never mutates the server.**

## When to use

- User says the server "feels hacked", is slow, or received a security alert
  (hosting-provider email, Telegram group notice, monitoring alert).
- Periodic hygiene check on any VPS / cloud box the user manages.
- After restoring from snapshot or regaining access to a server.

## Inputs

| Input | Required | Default |
|---|---|---|
| Target server | optional | current machine (`localhost`) |
| SSH destination | optional | `user@host` or ssh-config alias, incl. `-p port` |

If no target is given, audit the machine the agent is running on (works for
agents installed directly on the server).

## Workflow (agent-connected mode)

1. **Collect evidence** — run the bundled script remotely (no upload needed):

   ```bash
   ssh -p <port> <user>@<host> 'bash -s' < scripts/audit.sh
   ```

   or locally: `bash scripts/audit.sh`. Output is plain text, sectioned
   `=== [N] TITLE ===`, safe to paste to any LLM.

2. **Judge** — read `references/interpretation.md`. For each of the 12
   sections decide OK / SUSPICIOUS / CRITICAL, citing the exact line as
   evidence. When unsure, say "needs human review" instead of guessing.

3. **Report** — use this shape:

   ```
   ## Security Audit — <host>, <date/time>

   Overall: CLEAN | REVIEW NEEDED | LIKELY COMPROMISED

   | # | Check | Verdict | Evidence |
   |---|---|---|---|
   | 1 | UID-0 accounts | ✅ OK | only root |
   | 4 | Top CPU processes | ⚠️ SUSPICIOUS | /tmp/.x/kdevtmpfsi 380% CPU |

   ## Findings & recommended next steps
   - (ordered by severity, each with a concrete command or action)

   Scope note: read-only audit; nothing was changed on the server.
   ```

## Workflow (manual mode — no server access)

If the agent cannot SSH in (e.g. web-only chat like GLM/Claude web), instruct
the user to run locally on the server:

```bash
curl -sO <raw-url-of-audit.sh> && bash audit.sh > audit-out.txt
# then paste audit-out.txt back to the assistant
```

or copy the script content from this skill's `scripts/audit.sh`. Judge the
pasted output exactly as in step 2–3.

## Interpretation cheat-sheet (details in references/interpretation.md)

- UID-0 must be `root` only. A second UID-0 account is CRITICAL.
- Logins from unknown IPs/countries/hours → SUSPICIOUS; brute-force storms in
  `lastb` with zero success → OK-ish but recommend disabling password auth.
- CPU hogs running from `/tmp`, `/dev/shm`, `/var/tmp`, or hidden dot-dirs,
  or with gibberish/imitation names (`kdevtmpfsi`, `kinsing`,
  `x86_64+-+`, fake `[kworker/...]`) → classic miner, CRITICAL.
- Cron entries with `curl|wget … | bash`, /tmp paths, unknown domains → CRITICAL.
- `authorized_keys` count vs. what user expects; keys with `command="…"`
  restrictions are fine, unrestricted unknown keys are CRITICAL.
- Executables in `/tmp`/`/dev/shm` → CRITICAL (legit software doesn't live there).
- `/etc/ld.so.preload` non-empty → likely userland rootkit, CRITICAL.
- Outbound traffic is judged against the server's *business*: a proxy node
  (xray/hysteria/sing-box) relaying user traffic is normal; connections to
  IRC ports (6667), unknown mining pools, or bulk SMTP are not.

## Report delivery by channel

Adapt the report format to the delivery channel:

- **Default (terminal / web chat / clipboard / email)**: GFM markdown — pipe
  table (`| # | Check | Verdict |`) renders everywhere.
- **Feishu/Lark webhook card**: use schema-2.0 interactive card — elements
  live under `card.body.elements` (NOT `card.elements`); the list is a
  `table` component (columns + rows), which has **no `row_size` property**
  (error 11246); `note` elements are also rejected under 2.0 — use a grey
  markdown line instead. Verified working 2026-11. If card parse fails,
  fall back to one-line-per-check markdown in the same card.
- **Channels without table support** (e.g. Telegram): one line per check
  (`01 系统上下文　✅`), verdict emojis kept, details as plain lines.

Principle: use the channel's native table component when it has one;
otherwise fall back to the most portable markdown. Never dump raw pipe
table text into a channel that won't render it.

## Safety rules

- **Read-only**: never delete files, kill processes, edit configs, or "clean
  up" during the audit. Remediation is a separate, user-approved step.
- Evidence lines may contain IPs/paths/hostnames — fine for the user's own
  report, but do not post them to public channels without user consent.
- If a CRITICAL finding involves an active backdoor, recommend (do not run)
  the containment order: snapshot → revoke keys/passwords → offline triage.

## Files

- `scripts/audit.sh` — evidence collector (12 checks, Debian/Ubuntu, ~15 s)
- `references/interpretation.md` — per-check verdict table + remediation pointers
