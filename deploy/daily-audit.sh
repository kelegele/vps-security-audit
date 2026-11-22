#!/usr/bin/env bash
# Daily security audit -> Feishu interactive card (异常才展开详情).
# Webhook URL lives in /root/.pi/cron/feishu-webhook.txt (chmod 600).
# Cron: 0 1 * * * (UTC) = 09:00 Beijing.
set -u
DIR=/root/.pi/cron
OUT=$DIR/audit-last.txt
HOOK=$DIR/feishu-webhook.txt
LOG=$DIR/run.log

bash /root/.pi/agent/skills/vps-security-audit/scripts/audit.sh > "$OUT" 2>&1

if timeout 240 pi -p "File $OUT contains raw evidence from a 12-check security audit of this server. Read it, and read the judging standards in /root/.pi/agent/skills/vps-security-audit/references/interpretation.md. Judge all 12 sections. Then send a Feishu INTERACTIVE CARD to the webhook: read the URL from $HOOK. Write the card JSON to /tmp/audit-card.json using this exact structure (fill the placeholders):

{\"msg_type\":\"interactive\",\"card\":{\"config\":{\"wide_screen_mode\":true},\"header\":{\"template\":\"CARD_COLOR\",\"title\":{\"tag\":\"plain_text\",\"content\":\"HEADER_TEXT\"}},\"elements\":[{\"tag\":\"markdown\",\"content\":\"TABLE_MD\"},{\"tag\":\"markdown\",\"content\":\"DETAILS_MD\"},{\"tag\":\"note\",\"elements\":[{\"tag\":\"plain_text\",\"content\":\"NOTE_TEXT\"}]}]}}

KNOWN_IPS: if the file /root/pi-cron-context/known-ips.txt exists, read it: each IP/CIDR listed there is known-good owner or provider access (install/testing, owner exits); judge check [03] against it and only flag logins from IPs outside that list.
Rules:
- CARD_COLOR: green if all 12 checks OK, orange if any SUSPICIOUS, red if any CRITICAL.
- HEADER_TEXT: 🛡 每日安检报告 <hostname> (<public IP>) <北京时间 YYYY-MM-DD HH:MM> — must contain the word 安检; get the public IP from the audit evidence or run curl -s --max-time 8 https://api.ipify.org; Beijing time = UTC+8.
- TABLE_MD: a proper markdown table with header row | # | 检查项 | 结果 | then exactly 12 rows (01..12 with short Chinese check names), result cell ✅/⚠️/❌, aligned columns.
- DETAILS_MD: '**详情**' then for each non-OK check: bold 【NN】 name + one concise evidence line; if none: 全部通过，无异常 ✨.
- NOTE_TEXT: vps-security-audit · 12 checks · <verdict EN>.
Then POST it: curl -sS --max-time 15 -H 'Content-Type: application/json' -d @/tmp/audit-card.json \"\$(cat $HOOK)\" — verify the response JSON contains success; if not, fix the JSON and retry once. rm /tmp/audit-card.json afterwards. Post nothing else, then exit." >> "$LOG" 2>&1; then
  echo "$(date -u '+%F %T') pi OK" >> "$LOG"
else
  # heartbeat-failure fallback: silent cron failure must not look like "safe"
  curl -sS --max-time 15 -H "Content-Type: application/json" \
    -d '{"msg_type":"text","content":{"text":"安检兜底告警：'"$(hostname)"' 每日安检运行异常（pi 执行失败），请登服务器查 /root/.pi/cron/run.log"}}' \
    "$(cat "$HOOK" 2>/dev/null)" >> "$LOG" 2>&1
  echo "$(date -u '+%F %T') PI FAILED (fallback attempted)" >> "$LOG"
fi
