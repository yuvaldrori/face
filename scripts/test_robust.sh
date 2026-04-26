#!/bin/bash

PRG=$1
DEVICE=$2
MONKEYDO=$3

if [ -z "$PRG" ] || [ -z "$DEVICE" ] || [ -z "$MONKEYDO" ]; then
    echo "Usage: $0 <prg> <device> <monkeydo_path>"
    exit 1
fi

# 1. Check if simulator is listening
if ! ss -tuln | grep -q ":1234 "; then
    echo "ERROR: Simulator is not listening on port 1234."
    exit 1
fi

# 2. Run tests with a timeout to prevent hanging
# We use 'stdbuf' to ensure we get output line by line if possible
echo "Running tests for $DEVICE..."
OUTPUT_FILE=$(mktemp)
timeout 60s $MONKEYDO "$PRG" "$DEVICE" -t > "$OUTPUT_FILE" 2>&1
EXIT_CODE=$?

cat "$OUTPUT_FILE"

if [ $EXIT_CODE -eq 124 ]; then
    echo "ERROR: Test execution timed out (60s)."
    rm "$OUTPUT_FILE"
    exit 1
fi

# 3. Analyze output
if grep -q "PASSED" "$OUTPUT_FILE"; then
    echo "SUCCESS: Tests passed."
    rm "$OUTPUT_FILE"
    exit 0
elif grep -q "FAILED" "$OUTPUT_FILE"; then
    echo "FAILURE: Tests failed."
    rm "$OUTPUT_FILE"
    exit 1
elif grep -q "Error:" "$OUTPUT_FILE" || grep -q "Connection refused" "$OUTPUT_FILE"; then
    echo "ERROR: Connection or execution error detected."
    rm "$OUTPUT_FILE"
    exit 1
else
    echo "WARNING: Could not determine test result (no PASSED/FAILED found)."
    rm "$OUTPUT_FILE"
    exit 1
fi
