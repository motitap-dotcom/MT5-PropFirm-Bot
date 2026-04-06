#!/bin/bash
# Helper: wait for VPS output after triggering a workflow
# Usage: bash scripts/wait_for_output.sh <output_file> <branch> [max_wait_seconds]
OUTPUT_FILE="${1:-commands/output.txt}"
BRANCH="${2:-main}"
MAX_WAIT="${3:-300}"
INTERVAL=30

echo "Waiting for $OUTPUT_FILE to be updated on $BRANCH..."
BEFORE_SHA=$(git log -1 --format=%H -- "$OUTPUT_FILE" 2>/dev/null || echo "none")

elapsed=0
while [ $elapsed -lt $MAX_WAIT ]; do
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
    git fetch origin "$BRANCH" 2>/dev/null
    git reset --hard "origin/$BRANCH" 2>/dev/null
    AFTER_SHA=$(git log -1 --format=%H -- "$OUTPUT_FILE" 2>/dev/null || echo "none")

    if [ "$BEFORE_SHA" != "$AFTER_SHA" ]; then
        echo "Output updated after ${elapsed}s!"
        cat "$OUTPUT_FILE"
        exit 0
    fi
    echo "  ...${elapsed}s elapsed, still waiting"
done

echo "Timeout after ${MAX_WAIT}s - no output received"
exit 1
