#!/bin/bash
set -e

export PYTHONPATH=/workspace:$PYTHONPATH

echo "======================================"
echo " Running hidden validation suite"
echo "======================================"

python3 -m pytest tests/test_hidden_f7a3c192_validate.py \
    -v \
    -p no:pretty \
    --tb=short

EXIT_CODE=$?

echo "======================================"
echo " Validation complete (exit: $EXIT_CODE)"
echo "======================================"

exit $EXIT_CODE
