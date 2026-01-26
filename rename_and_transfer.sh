#!/bin/bash
set -e

SOURCE_LOCAL_PATH=$1
PROCESSING_GCS_PATH=$2
ARCHIVE_GCS_PATH=$3

TMP_DIR=/tmp/rdl_demo
mkdir -p "$TMP_DIR"

# find csv file
FILE_NAME=$(find "$SOURCE_LOCAL_PATH" -type f -name "*.csv" | head -1)

if [ -z "$FILE_NAME" ]; then
    echo "❌ No CSV file found"
    exit 1
fi

BASENAME=$(basename "$FILE_NAME")

echo "Found file: $BASENAME"

# copy to working dir
cp "$FILE_NAME" "$TMP_DIR/"

LOCAL_SOURCE="$TMP_DIR/$BASENAME"

# extract batch date
BATCH_DATE=$(echo "$BASENAME" | grep -oE '[0-9]{8}')

if [ -z "$BATCH_DATE" ]; then
    echo "❌ Batch date not found"
    exit 1
fi

NEW_FILE="GB1_TRANSACTION_DAILY_${BATCH_DATE}.csv"
LOCAL_FILE="$TMP_DIR/$NEW_FILE"

# rename
mv "$LOCAL_SOURCE" "$LOCAL_FILE"

# row count (exclude header)
TOTAL_LINES=$(wc -l < "$LOCAL_FILE")
ROW_COUNT=$((TOTAL_LINES - 1))

if [ "$ROW_COUNT" -lt 0 ]; then
    ROW_COUNT=0
fi

FORMATTED_DATE=$(date -d "$BATCH_DATE" +"%d-%b-%Y")

# append footer
printf "\n<DATE> %s <ROWS> %s\n" "$FORMATTED_DATE" "$ROW_COUNT" >> "$LOCAL_FILE"

# upload to processing
gsutil cp "$LOCAL_FILE" "$PROCESSING_GCS_PATH/$NEW_FILE"

# archive original local file to GCS
gsutil mv \
gs://rdl_demo_project_bucket/landing/$(basename "$FILE_NAME") \
$ARCHIVE_GCS_PATH/$(basename "$FILE_NAME")

echo "✅ Rename + footer + archive completed"
