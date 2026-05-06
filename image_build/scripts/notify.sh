#!/bin/bash
# notify.sh — stubbed notification script
# In a real pipeline this would call Slack, PagerDuty, etc.
# Here it just logs to a file the tests can inspect if needed.

STATUS="${1:-unknown}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/workspace/notifications.log"

mkdir -p /workspace
echo "[$TIMESTAMP] Pipeline notification: $STATUS" >> "$LOG_FILE"
echo "[notify] Sent notification: $STATUS"

exit 0