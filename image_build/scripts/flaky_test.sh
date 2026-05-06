#!/bin/bash

# ------------------------------------------------------------
# flaky_test.sh
#
# Simulates a test suite that is intentionally unreliable.
# In the broken pipeline, this flakiness is used to expose
# the catchError misconfiguration — the pipeline should halt
# on failure but currently does not.
#
# Behavior:
#   - Always prints test output to stdout
#   - Exits 0 (pass) or 1 (fail) based on a seeded condition
#     tied to the current minute, so it alternates predictably
#     in a test environment rather than being truly random
# ------------------------------------------------------------

echo "======================================"
echo " Running Test Suite"
echo "======================================"
echo ""

echo "[TEST 1] Checking application config format..."
sleep 1
echo "  PASS: config.yaml is valid"

echo "[TEST 2] Checking database connection string..."
sleep 1
echo "  PASS: connection string present"

echo "[TEST 3] Running unit tests..."
sleep 1

# Seeded flakiness: fail on even minutes, pass on odd
# This makes behavior deterministic for local testing
# while still exposing the control flow bug
MINUTE=$(date +%M)
REMAINDER=$((MINUTE % 2))

if [ $REMAINDER -eq 0 ]; then
    echo "  FAIL: 3 unit tests failed"
    echo ""
    echo "======================================"
    echo " Test Suite FAILED (exit 1)"
    echo "======================================"
    exit 1
else
    echo "  PASS: all unit tests passed"
    echo ""
    echo "======================================"
    echo " Test Suite PASSED (exit 0)"
    echo "======================================"
    exit 0
fi