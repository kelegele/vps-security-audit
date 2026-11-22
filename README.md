# vps-security-audit

Read-only security audit skill for Linux servers. An AI agent runs 12
evidence checks over SSH (or locally), judges the output against a built-in
interpretation table, and returns a graded report — CLEAN / REVIEW NEEDED /
LIKELY COMPROMISED — with evidence for every finding.

Works with any agent that supports the SKILL.md convention (Claude Code,
Pi, OpenCode, Codex, …), and in "manual mode" with web chatbots (paste the
output to GLM / ChatGPT / Claude web).

## Why

Hosting-provider security alerts ("your server may be compromised, please
check") arrive with zero guidance. Human checklists are hard to remember.
This skill turns a battle-tested 12-check routine into one sentence:
*"security-audit my server"*.

The niche was empty at time of writing — existing "security audit" skills
target code/WordPress/mini-programs, not Linux servers.

## Install

```bash
npx skills add <repo-url>        # if published
# or copy the folder into your agent's skills directory:
cp -r vps-security-audit ~/.agents/skills/
```

## Checks (all read-only, ~15 s)

| # | Check | Catches |
|---|---|---|
| 01 | System context | tampering tells (uptime vs story) |
| 02 | UID-0 & shell accounts | privileged backdoor users |
| 03 | Login history & brute-force | intruder logins, credential stuffing |
| 04 | Top CPU processes | crypto miners (kdevtmpfsi et al.) |
| 05 | Cron jobs (root + all users) | download-and-run miners, beacons |
| 06 | Running services & new units | fake systemd services |
| 07 | Listening & outbound connections | C2, exfil, mining pools |
| 08 | SSH keys & sshd config | rogue authorized_keys |
| 09 | /tmp /var/tmp /dev/shm | dropped executables |
| 10 | Recent /etc changes | persistence tampering |
| 11 | ld.so.preload | userland rootkits |
| 12 | New SUID / promisc NIC / fail2ban | privilege-escalation & sniffer traces |

## Usage

Say to your agent:

- “安检一下服务器” / "security-audit my server"
- "check my VPS for miners / backdoors"
- "hosting provider sent a security alert — audit the box"

Agent mode: the agent pipes `scripts/audit.sh` over SSH and reports.
Manual mode: you run the script on the server and paste the output to any
web chatbot — the skill files double as the prompt.

```bash
ssh -p <port> user@host 'bash -s' < scripts/audit.sh
# paste output to your AI, or read references/interpretation.md yourself
```

## Safety

Evidence collection is strictly read-only: no deletions, no process kills,
no config edits. Remediation is always a separate, user-approved step.

Reports may contain sensitive details (IPs, ports, usernames) — share
thoughtfully.

## License

MIT
