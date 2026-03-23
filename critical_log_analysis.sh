#!/bin/bash

LOG_FILE="sys_log.txt"
OUTPUT_FILE="top10_critical.txt"

# Check if log file exists
if [[ ! -f "$LOG_FILE" ]]; then
    echo "ERROR: $LOG_FILE not found."
    exit 1
fi

# Step 1 - Filter critical log lines
filtered_lines=$(grep -iE "ERROR|CRITICAL|FATAL" "$LOG_FILE")

# Check if any matching lines were found
if [[ -z "$filtered_lines" ]]; then
    echo "No ERROR, CRITICAL, or FATAL lines found."
    exit 0
fi

# Step 2 - Tokenize filtered lines
tokens=$(echo "$filtered_lines" \
    | tr '[:space:]' '\n' \
    | sed 's/[^a-zA-Z0-9]//g' \
    | grep -v '^$')

# Step 3 - Count frequency and display top 10
top10=$(echo "$tokens" | sort | uniq -c | sort -rn | head -10)

echo "$top10"

# Step 4 - Save results to file
echo "$top10" > "$OUTPUT_FILE"

echo "Results saved to $OUTPUT_FILE"
