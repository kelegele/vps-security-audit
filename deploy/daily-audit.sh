#!/usr/bin/env bash
# Daily security audit -> Feishu webhook (异常才展开).
# Webhook URL lives in /root/.pi/cron/feishu-webhook.txt (chmod 600).
# Cron: 0 1 * * * (UTC) = 09:00 Beijing.
set -u
DIR=/root/.pi/cron
OUT=$DIR/audit-last.txt
HOOK=$DIR/feishu-webhook.txt
LOG=$DIR/run.log

bash /root/.pi/agent/skills/vps-security-audit/scripts/audit.sh > "$OUT" 2>&1

if timeout 240 pi -p "File $OUT contains raw evidence from a 12-check security audit of this server. Read it, and read the judging standards in /root/.pi/agent/skills/vps-security-audit/references/interpretation.md. Judge all 12 sections. Then send the report to Feishu: read the webhook URL from $HOOK and POST it with curl a JSON body {\"msg_type\":\"text\",\"content\":{\"text\":\"...\"}} (Content-Type: application/json). The text MUST follow this exact layout (the title line must contain the word 安检 and the server public IP - get it from the audit evidence or `curl -s --max-time 8 https://api.ipify.org`; Beijing time = UTC+8):\n【每日安检报告】<hostname> (<public IP>) <北京时间 YYYY-MM-DD HH:MM>\n<12 lines, one per check: ✅/⚠️/❌ [NN] <check name>\n详情：\n<for each non-OK check: one short evidence snippet; if none: 全部通过，无异常>\nNothing after the details. Post nothing else, then exit." >> "$LOG" 2>&1; then
  echo "$(date -u '+%F %T') pi OK" >> "$LOG"
else
  # heartbeat-failure fallback: silent cron failure must not look like "safe"
  curl -sS --max-time 15 -H "Content-Type: application/json" \
    -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"⚠️ 每日安检运行异常 ($(hostname) $(date -u '+%F %T'))：pi 执行失败，请登服务器查 $LOG\"}}" \
    "$(cat "$HOOK" 2>/dev/null)" >> "$LOG" 2>&1
  echo "$(date -u '+%F %T') PI FAILED (fallback attempted)" >> "$LOG"
fi
