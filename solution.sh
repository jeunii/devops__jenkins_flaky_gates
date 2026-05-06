#!/bin/bash
set -e

CONFIG="/var/lib/jenkins/jobs/flaky-pipeline/config.xml"

# Fix 1: Replace catchError that masks test failure with a direct call
# so a failing test propagates and blocks Deploy
sed -i 's|catchError(buildResult: '"'"'SUCCESS'"'"', stageResult: '"'"'FAILURE'"'"') {||' "$CONFIG"
sed -i '/sh .\/usr\/local\/bin\/flaky_test.sh./{ n; s|}||; }' "$CONFIG"

# Fix 2: Fix the inverted when condition on Approve stage
# Remove the wrapping `not` so approval is required ON main
sed -i 's|not {||' "$CONFIG"
sed -i '/branch .main./{ n; s|}||; }' "$CONFIG"

# Fix 3: Add failure notification to post block
sed -i "s|post {|post {\n        failure {\n            sh '/usr/local/bin/notify.sh failure'\n        }|" "$CONFIG"

# Reload Jenkins job config
curl -s -X POST http://admin:admin@localhost:8080/job/flaky-pipeline/reload