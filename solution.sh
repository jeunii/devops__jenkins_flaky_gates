#!/bin/bash
set -e

CONFIG="/var/lib/jenkins/jobs/flaky_pipeline/config.xml"

echo "[solution] Patching config.xml..."

python3 << 'PYEOF'
import xml.etree.ElementTree as ET
import re

config_path = "/var/lib/jenkins/jobs/flaky_pipeline/config.xml"

tree = ET.parse(config_path)
root = tree.getroot()
script_node = root.find('.//script')
assert script_node is not None, "ERROR: No <script> tag found"
groovy = script_node.text

# Fix 1: Remove catchError wrapper
groovy = re.sub(
    r"\s*catchError\(buildResult:\s*'SUCCESS',\s*stageResult:\s*'FAILURE'\)\s*\{",
    "",
    groovy
)
groovy = re.sub(
    r"(sh\s+'/usr/local/bin/flaky_test\.sh')\s*\n(\s*\})",
    r"\1",
    groovy
)
print("[solution] Fix 1 applied: catchError removed")

# Fix 2: Remove `not` wrapper on Approve when condition
groovy = re.sub(
    r"not\s*\{\s*\n(\s*branch\s+'main')\s*\n\s*\}",
    r"\1",
    groovy
)
print("[solution] Fix 2 applied: not{} wrapper removed")

# Fix 3: Add failure block to post section
if "failure {" not in groovy:
    groovy = groovy.replace(
        "        success {",
        "        failure {\n            sh \"${NOTIFY_SCRIPT} failure\"\n        }\n        success {"
    )
print("[solution] Fix 3 applied: failure block added")

script_node.text = groovy
tree.write(config_path, encoding='unicode', xml_declaration=False)
print("[solution] config.xml written")

# Verify
tree2 = ET.parse(config_path)
script2 = tree2.getroot().find('.//script').text
assert "catchError(buildResult: 'SUCCESS'" not in script2, "Fix 1 FAILED"
assert "not {\n" not in script2, "Fix 2 FAILED"
assert "failure {" in script2, "Fix 3 FAILED"
print("[solution] All 3 fixes verified")
PYEOF

echo "[solution] Reloading Jenkins..."
curl -s -X POST http://admin:admin@localhost:8081/job/flaky_pipeline/reload \
    || echo "[solution] WARN: reload returned error"

echo "[solution] Done."
