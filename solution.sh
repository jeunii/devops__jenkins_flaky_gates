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

# Robust script node finder:
# Works whether root IS <script>, or <script> is nested inside flow-definition
script_node = None

# Case 1: root is the script tag itself (fragment-only file)
if root.tag == 'script' and root.text and 'pipeline {' in root.text:
    script_node = root

# Case 2: script is nested inside flow-definition (full Jenkins XML)
if script_node is None:
    script_node = root.find('.//script')

# Case 3: namespace-prefixed tags - search by local name
if script_node is None:
    for elem in root.iter():
        local = elem.tag.split('}')[-1] if '}' in elem.tag else elem.tag
        if local == 'script' and elem.text and 'pipeline {' in elem.text:
            script_node = elem
            break

assert script_node is not None, \
    "ERROR: Could not find <script> node containing pipeline definition"

groovy = script_node.text
print(f"[solution] Script node found, length={len(groovy)}")

# ------------------------------------------------------------------
# Fix 1: Remove catchError wrapper that masks test failures
# Before:
#   catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
#       sh '/usr/local/bin/flaky_test.sh'
#   }
# After:
#   sh '/usr/local/bin/flaky_test.sh'
# ------------------------------------------------------------------
if "catchError(buildResult: 'SUCCESS'" in groovy:
    groovy = re.sub(
        r"\s*catchError\(buildResult:\s*'SUCCESS',\s*stageResult:\s*'FAILURE'\)\s*\{",
        "",
        groovy
    )
    # Remove the orphaned closing brace left after catchError is removed
    groovy = re.sub(
        r"(sh\s+'/usr/local/bin/flaky_test\.sh')\s*\n(\s*\})",
        r"\1",
        groovy
    )
    print("[solution] Fix 1 applied: catchError removed")
else:
    print("[solution] Fix 1 skipped: catchError not found")

# ------------------------------------------------------------------
# Fix 2: Remove `not` wrapper on Approve when condition
# Before:
#   when { not { branch 'main' } }
# After:
#   when { branch 'main' }
# ------------------------------------------------------------------
if "not {" in groovy:
    groovy = re.sub(
        r"not\s*\{\s*\n(\s*branch\s+'main')\s*\n\s*\}",
        r"\1",
        groovy
    )
    print("[solution] Fix 2 applied: not{} wrapper removed")
else:
    print("[solution] Fix 2 skipped: not{} not found")

# ------------------------------------------------------------------
# Fix 3: Add failure block to post section
# Before:
#   post { success { ... } }
# After:
#   post { failure { ... } success { ... } }
# ------------------------------------------------------------------
if "failure {" not in groovy:
    groovy = groovy.replace(
        "        success {",
        "        failure {\n            sh \"${NOTIFY_SCRIPT} failure\"\n        }\n        success {"
    )
    print("[solution] Fix 3 applied: failure block added")
else:
    print("[solution] Fix 3 skipped: failure block already present")

# Write back
script_node.text = groovy
tree.write(config_path, encoding='unicode', xml_declaration=False)
print("[solution] config.xml written successfully")

# ------------------------------------------------------------------
# Verify all 3 fixes by re-parsing
# ------------------------------------------------------------------
tree2 = ET.parse(config_path)
root2 = tree2.getroot()

script2_node = None
if root2.tag == 'script' and root2.text and 'pipeline {' in root2.text:
    script2_node = root2
if script2_node is None:
    script2_node = root2.find('.//script')
if script2_node is None:
    for elem in root2.iter():
        local = elem.tag.split('}')[-1] if '}' in elem.tag else elem.tag
        if local == 'script' and elem.text and 'pipeline {' in elem.text:
            script2_node = elem
            break

assert script2_node is not None, "VERIFY FAILED: could not re-read script after write"
script2 = script2_node.text

assert "catchError(buildResult: 'SUCCESS'" not in script2, \
    "VERIFY FAILED: Fix 1 - catchError still present"
assert "not {\n" not in script2, \
    "VERIFY FAILED: Fix 2 - not{} wrapper still present"
assert "failure {" in script2, \
    "VERIFY FAILED: Fix 3 - failure block missing"
assert "notify.sh" in script2, \
    "VERIFY FAILED: Fix 3 - notify.sh call missing"

print("[solution] All 3 fixes verified successfully")
PYEOF

echo "[solution] Reloading Jenkins..."
curl -s -X POST http://admin:admin@localhost:8081/job/flaky_pipeline/reload \
    || echo "[solution] WARN: reload returned error"

echo "[solution] Done."