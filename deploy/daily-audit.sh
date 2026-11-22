#!/usr/bin/env bash
# Daily security audit -> Feishu interactive card v2 (table layout, 异常才展开详情).
# Webhook URL lives in /root/.pi/cron/feishu-webhook.txt (chmod 600).
# Card JSON gotchas verified on this webhook (2026-11-23):
#   - must use schema 2.0: elements live under card.body.elements (not card.elements)
#   - v2 table component works, but has NO row_size property (err 11246/200621)
# Cron: 0 1 * * * (UTC) = 09:00 Beijing.
set -u
DIR=/root/.pi/cron
OUT=$DIR/audit-last.txt
HOOK=$DIR/feishu-webhook.txt
LOG=$DIR/run.log

bash /root/.pi/agent/skills/vps-security-audit/scripts/audit.sh > "$OUT" 2>&1

if timeout 240 pi -p "File $OUT contains raw evidence from a 12-check security audit of this server. Read it, and read the judging standards in /root/.pi/agent/skills/vps-security-audit/references/interpretation.md. KNOWN_IPS: if /root/pi-cron-context/known-ips.txt exists, read it - each IP/CIDR there is known-good owner/provider access; judge check [03] against it and only flag logins from IPs outside that list. Judge all 12 sections. Then send a Feishu interactive card to the webhook: read the URL from $HOOK. Write the card JSON to /tmp/audit-card.json with msg_type interactive and this EXACT schema-2.0 structure (elements go under card.body.elements, NOT card.elements):

{\"msg_type\":\"interactive\",\"card\":{\"schema\":\"2.0\",\"config\":{\"wide_screen_mode\":true},\"header\":{\"title\":{\"tag\":\"plain_text\",\"content\":\"HEADER_TEXT\"},\"template\":\"CARD_COLOR\"},\"body\":{\"elements\":[{\"tag\":\"table\",\"page_size\":12,\"columns\":[{\"name\":\"no\",\"display_name\":\"#\",\"data_type\":\"text\",\"width\":\"auto\"},{\"name\":\"item\",\"display_name\":\"检查项\",\"data_type\":\"text\",\"width\":\"auto\"},{\"name\":\"result\",\"display_name\":\"结果\",\"data_type\":\"text\",\"width\":\"auto\"}],\"rows\":[{\"no\":\"01\",\"item\":\"系统上下文\",\"result\":\"✅\"}]},{\"tag\":\"markdown\",\"content\":\"DETAILS_MD\"},{\"tag\":\"note\",\"elements\":[{\"tag\":\"plain_text\",\"content\":\"NOTE_TEXT\"}]}]}}}

Fill rules:
- rows: exactly 12 entries (no 01..12, short Chinese check names, result ✅/⚠️/❌). The table component has NO row_size property - do not add it (causes error 11246).
- CARD_COLOR: green if all 12 OK, orange if any SUSPICIOUS, red if any CRITICAL.
- HEADER_TEXT: 🛡 每日安检报告 <hostname> (<public IP>) <北京时间 YYYY-MM-DD HH:MM> - must contain the word 安检; public IP from the audit evidence or curl -s --max-time 8 https://api.ipify.org; Beijing time = UTC+8.
- DETAILS_MD: '**详情**' then for each non-OK check: bold 【NN】 name + one concise evidence line; if none: 全部通过，无异常 ✨.
- NOTE_TEXT: vps-security-audit · 12 checks · <verdict EN>.
Then POST: curl -sS --max-time 15 -H 'Content-Type: application/json' -d @/tmp/audit-card.json \"\$(cat $HOOK)\". If the response reports a card parse error, fix per the error message and retry up to twice; if it still fails, fall back to a schema-2.0 card with the same header but a single markdown element using one line per check (e.g. '01 系统上下文　✅'). rm /tmp/audit-card.json afterwards. Post nothing else, then exit." >> "$LOG" 2>&1; then
  echo "$(date -u '+%F %T') pi OK" >> "$LOG"
else
  # heartbeat-failure fallback: silent cron failure must not look like "safe"
  curl -sS --max-time 15 -H "Content-Type: application/json" \
    -d '{"msg_type":"text","content":{"text":"安检兜底告警：'"$(hostname)"' 每日安检运行异常（pi 执行失败），请登服务器查 /root/.pi/cron/run.log"}}' \
    "$(cat "$HOOK" 2>/dev/null)" >> "$LOG" 2>&1
  echo "$(date -u '+%F %T') PI FAILED (fallback attempted)" >> "$LOG"
fi
