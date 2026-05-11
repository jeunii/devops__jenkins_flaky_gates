import xml.etree.ElementTree as ET
import os

CONFIG = "/var/lib/jenkins/jobs/flaky_pipeline/config.xml"

def get_jenkinsfile():
    assert os.path.exists(CONFIG), f"config.xml not found at {CONFIG}"
    tree = ET.parse(CONFIG)
    root = tree.getroot()

    # Robust finder: works with full Jenkins XML or bare script fragment
    script = None

    # Case 1: root IS the script tag (fragment-only file)
    if root.tag == 'script' and root.text and 'pipeline {' in root.text:
        script = root

    # Case 2: script nested inside flow-definition
    if script is None:
        script = root.find('.//script')

    # Case 3: namespace-prefixed tags
    if script is None:
        for elem in root.iter():
            local = elem.tag.split('}')[-1] if '}' in elem.tag else elem.tag
            if local == 'script' and elem.text and 'pipeline {' in elem.text:
                script = elem
                break

    assert script is not None, "No <script> tag found in config.xml"
    return script.text or ""

def test_catchError_removed():
    """Deploy should not run if Test fails - catchError must not mask failures"""
    jenkinsfile = get_jenkinsfile()
    assert "catchError(buildResult: 'SUCCESS'" not in jenkinsfile, \
        "catchError is still masking test failures"

def test_approve_gate_correct():
    """Approve stage should require approval on main, not bypass it"""
    jenkinsfile = get_jenkinsfile()
    assert "not {\n                not {" not in jenkinsfile, \
        "Approve gate is still inverted"
    assert "branch 'main'" in jenkinsfile, \
        "branch condition missing from Approve stage"

def test_failure_notification_exists():
    """Post block must include a failure handler"""
    jenkinsfile = get_jenkinsfile()
    assert "failure {" in jenkinsfile, \
        "No failure block found in post section"
    assert "notify.sh" in jenkinsfile, \
        "notify.sh call missing from failure block"