#!/bin/bash

# Ensure exactly one directory argument is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

DIRECTORY="$1"

# Check if the provided directory exists
if [ ! -d "$DIRECTORY" ]; then
  echo "Error: The provided directory does not exist."
  exit 1
fi

# Set up the SQLite database
DB_FILE="checked_files.db"
sqlite3 $DB_FILE "CREATE TABLE IF NOT EXISTS checked_files (filepath TEXT PRIMARY KEY);" || { echo "Error setting up database."; exit 1; }

# Function for logging
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_message "Starting file processing in directory $DIRECTORY"

# Prepare a buffer for batching
BATCH_SIZE=200
file_count=0
batch="BEGIN TRANSACTION;"

# Find and process video files
find "$DIRECTORY" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" \) 2>/dev/null | while IFS= read -r FILE
do
  log_message "Processing file: $FILE"
  
  EXISTS=$(sqlite3 $DB_FILE "SELECT COUNT(*) FROM checked_files WHERE filepath = '$FILE';")
  if [ "$EXISTS" -eq 0 ]; then
    log_message "Checking: $FILE"
    
    # Simulate file checking logic
    if echo "$FILE" | grep -q "mp4"; then
      log_message "File $FILE seems fine."
    else
      log_message "File $FILE might require further checks."
    fi

    # Add the insertion statement to the batch
    batch+="INSERT INTO checked_files (filepath) VALUES ('$FILE');"
    ((file_count++))

    # Check if we've reached the batch size
    if [ "$file_count" -ge "$BATCH_SIZE" ]; then
      batch+="COMMIT;"
      echo "$batch" | sqlite3 $DB_FILE || log_message "Error inserting batch to database."
      batch="BEGIN TRANSACTION;"
      file_count=0
    fi

    # Optional decrease in operational pace for unloaded strain
    sleep 0.1  # Adjust sleep time as necessary
  else
    log_message "File $FILE already checked."
  fi
done

# After processing all files, commit remaining batch if not empty
if [ "$file_count" -gt 0 ]; then
  batch+="COMMIT;"
  echo "$batch" | sqlite3 $DB_FILE || log_message "Error inserting final batch to database."
fi

log_message "File processing complete."
