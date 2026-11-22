# Interpretation Table

Per-check verdict standards for `audit.sh` output. Verdicts: **OK** /
**SUSPICIOUS** (needs human review) / **CRITICAL** (act now).

> General principle: judge everything against *this server's known business*.
> A proxy node relaying traffic is normal for that server; the same traffic
> on a blog VPS is an incident. When in doubt, say "needs human review".

## [01] System context
Not a verdict — context. Note uptime (a "hacked for months" story breaks if
uptime is 2 days), kernel version, and timezone for reading login history.

## [02] UID-0 accounts
- OK: only `root` has UID 0.
- CRITICAL: any second UID-0 account (`awk` line beyond root) — classic
  backdoor. Also CRITICAL: unknown shell accounts in the tail list.
- SUSPICIOUS: sudo group members the user can't explain.

## [03] Login history
- OK: all IPs/countries belong to the owner (their home/office/VPN exits).
- SUSPICIOUS: unknown IP at odd hours; successful login right after a
  `lastb` brute-force storm from the same IP.
- OK-ish: `lastb` full of failures with zero matching success → noise;
  recommend disabling password authentication as follow-up.
- Cross-check [01]: if `last` output looks too clean or wtmp is oddly
  truncated, SUSPICIOUS (log tampering).

## [04] Top CPU processes
- CRITICAL (classic miner): process running from `/tmp`, `/dev/shm`,
  `/var/tmp`, or a hidden dot-directory (`.x/`, `.config/…`), or names like
  `kdevtmpfsi`, `kinsing`, `pools`, `xmr`, random hex strings; also fake
  kernel threads — a real `[kworker/u12:2]` never has a filesystem path.
- OK: expected business processes (nginx, xray, hysteria, sing-box,
  dockerd, fail2ban…) — but verify the binary path is standard
  (`/usr/bin/`, `/usr/local/bin/`, not `/tmp`).
- SUSPICIOUS: any long-running process at sustained >80% CPU whose name the
  user can't identify.

## [05] Cron
- CRITICAL: entries with `curl … | bash`, `wget … ; chmod +x`, /tmp paths,
  base64 blobs, unknown domains/IPs. Also check `@reboot` lines.
- OK: `acme.sh` renewals, package-manager standard jobs, logrotate.
- SUSPICIOUS: crontabs for users who shouldn't have them.

## [06] Running services
- CRITICAL: service whose ExecStart points into `/tmp`/`/dev/shm`, or a
  unit created recently with a random name (`systemd-xxxx.service` outside
  the official namespace is a known miner pattern).
- OK: expected stack + `unattended-upgrades`, `fail2ban`, cron/ssh.
- SUSPICIOUS: units modified in the last 30 days that aren't from package
  upgrades the user remembers.

## [07] Network
- OK: listening ports = known business (ssh, web, proxy ports, panel) +
  standard local traffic.
- CRITICAL: outbound connections to IRC (6667), known mining pool ports
  (3333+ stratum), bulk SMTP from a non-mail server, or any steady foreign
  connection the business can't explain.
- SUSPICIOUS: ESTAB connections in large count to a single unknown IP
  (exfil or C2 beacon); repeated short-lived connections to random IPs on
  high ports (scanning/worm behavior).
- Note: proxy services (xray/hysteria/sing-box) normally show many ESTAB
  connections on their service port — match them to the panel's user list
  before judging.

## [08] SSH
- CRITICAL: any `authorized_keys` entry the owner doesn't recognize.
- OK: keys with restrictions (`command="…",no-pty,no-port-forwarding…`)
  only if the user knows their purpose (monitoring agents, backups).
- SUSPICIOUS: `PermitRootLogin yes` + `PasswordAuthentication yes` on a
  public server — not a compromise, but a standing risk; recommend
  key-only auth.

## [09] /tmp & friends
- CRITICAL: any executable or ELF in `/tmp`, `/var/tmp`, `/dev/shm`.
  Legitimate software does not run from world-writable temp dirs.
- OK: sockets (`*.sock`), systemd-private dirs, sess_* files.

## [10] Recent /etc changes
- SUSPICIOUS: unexpected changes to `sshd_config`, `sudoers`, `passwd`,
  `rc.local`, `crontab` outside planned maintenance.
- OK: apt/dpkg-related churn, unattended-upgrades, fail2ban jail updates.

## [11] Preload / rootkit traces
- CRITICAL: non-empty `/etc/ld.so.preload`, or processes with `LD_PRELOAD`
  set that aren't from a known tool (rare; games/profilers on desktops,
  essentially never on servers). Userland rootkits hook libc via this file.
- NOTE: if multiple checks came back "odd but not conclusive" (e.g. wtmp
  truncated + a missing process + a renamed binary), suspect a kernel-mode
  rootkit — evidence from inside the box is untrustworthy; recommend
  verifying from outside (compare `ss` output with an external port scan,
  boot a live ISO for forensics).

## [12] SUID / promisc / fail2ban
- CRITICAL: new SUID binaries in unexpected places (`/tmp`, `/home`,
  `/dev/shm`); legit new SUID appears only right after package installs.
- CRITICAL: NIC in promisc mode without a known reason (sniffer running).
- OK: fail2ban absent (informational) or present with modest ban counts.

## Report grading

- All checks OK → **CLEAN**.
- Any SUSPICIOUS without CRITICAL → **REVIEW NEEDED** (list open questions).
- Any CRITICAL → **LIKELY COMPROMISED**. Recommended containment order
  (advise, don't execute): snapshot/backup → rotate all credentials and
  SSH keys → identify persistence (cron/units/keys) → offline forensics or
  rebuild-from-scratch if persistence is confirmed.
