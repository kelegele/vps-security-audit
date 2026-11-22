#!/usr/bin/env bash
# audit.sh — read-only security evidence collector for Debian/Ubuntu servers.
# Usage: bash audit.sh            (print to stdout; redirect to save: > out.txt)
# No arguments to target host needed: run it ON the server (or pipe via ssh).
# 12 checks, ~15 s. Collects evidence only — changes nothing.

set -u

section() { printf '\n=== [%02d] %s ===\n' "$1" "$2"; }

# 01 — system context
section 1 "SYSTEM CONTEXT"
hostname; uname -r; uptime; date -u '+UTC: %Y-%m-%d %H:%M:%S'
grep PRETTY /etc/os-release 2>/dev/null | cut -d'"' -f2

# 02 — privileged accounts
section 2 "UID-0 ACCOUNTS (expect only root)"
awk -F: '$3==0{print $1" uid="$3" shell="$7}' /etc/passwd
echo "--- sudo group ---"
getent group sudo 2>/dev/null || grep -E '^sudo:' /etc/group
echo "--- accounts with shells (last 15 in passwd) ---"
grep -E '(bash|zsh|sh|dash)$' /etc/passwd | tail -15

# 03 — logins
section 3 "LOGIN HISTORY (last 15 successful)"
last -15 2>/dev/null || echo "wtmp unavailable"
echo "--- failed logins (last 10) ---"
lastb -10 2>/dev/null | head -10 || echo "btmp unavailable"
echo "--- currently logged in ---"
w 2>/dev/null || who

# 04 — top CPU processes
section 4 "TOP 12 PROCESSES BY CPU"
ps aux --sort=-%cpu | head -13

# 05 — cron jobs
section 5 "CRON"
echo "--- root crontab ---"
crontab -l 2>/dev/null || echo "(empty/none)"
echo "--- /etc/cron.d ---"
ls -la /etc/cron.d/ 2>/dev/null
grep -rH . /etc/cron.d/ 2>/dev/null | head -20
echo "--- /etc/crontab ---"
grep -v '^#' /etc/crontab 2>/dev/null | grep -v '^$'
echo "--- other users' crontabs ---"
ls -la /var/spool/cron/crontabs/ 2>/dev/null || echo "(none)"

# 06 — running services
section 6 "RUNNING SERVICES"
systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | awk '{print $1}'
echo "--- units modified in last 30 days ---"
find /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system -name '*.service' -mtime -30 2>/dev/null

# 07 — network
section 7 "LISTENING PORTS"
ss -tulpn 2>/dev/null | grep -v '127.0.0.1\|::1' || netstat -tulpn 2>/dev/null
echo "--- ESTABLISHED outbound (non-local, sample) ---"
ss -tnp 2>/dev/null | grep ESTAB | grep -v '127.0.0.1\|::1' | head -25

# 08 — SSH
section 8 "SSH"
echo "--- authorized_keys (per user) ---"
for d in /root /home/*; do
  f="$d/.ssh/authorized_keys"
  [ -f "$f" ] && { echo "[$f] $(wc -l < "$f") key(s):"; awk '{print substr($1,1,20)"... "$NF}' "$f"; }
done
echo "--- sshd effective config (key items) ---"
sshd -T 2>/dev/null | grep -Ei 'permitrootlogin|passwordauthentication|pubkeyauthentication' || grep -Ei 'permitrootlogin|passwordauthentication' /etc/ssh/sshd_config

# 09 — world-writable temp dirs
section 9 "TMP / DEV/SHM (files)"
find /tmp /var/tmp /dev/shm -type f 2>/dev/null | head -30
echo "--- executables there ---"
find /tmp /var/tmp /dev/shm -type f -executable 2>/dev/null | head -10

# 10 — recent /etc changes
section 10 "/etc FILES MODIFIED IN 7 DAYS"
find /etc -type f -mtime -7 2>/dev/null | head -20

# 11 — rootkit traces (userland preload)
section 11 "LD.PRELOAD / ld.so.preload"
echo "--- /etc/ld.so.preload ---"
cat /etc/ld.so.preload 2>/dev/null || echo "(absent/empty — good)"
echo "--- process env with LD_PRELOAD (sample) ---"
grep -l LD_PRELOAD /proc/*/environ 2>/dev/null | head -5 || echo "(none)"

# 12 — misc: SUID new / promisc NIC / fail2ban
section 12 "SUID NEW(30d) / NIC PROMISC / FAIL2BAN"
echo "--- SUID files created in 30d ---"
find / -xdev -perm -4000 -type f -mtime -30 2>/dev/null
echo "--- NIC promiscuous mode ---"
ip -o link show 2>/dev/null | grep -i promisc || echo "(none — good)"
echo "--- fail2ban ---"
fail2ban-client status 2>/dev/null || echo "(not installed)"

section 99 "END"
echo "Evidence collection complete."
