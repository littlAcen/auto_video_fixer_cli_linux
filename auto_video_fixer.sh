#!/bin/bash

# Verify that a single argument has been supplied.
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

# Assign the provided directory to a variable.
DIRECTORY="$1"

# Verify the provided argument is a valid directory.
if [ ! -d "$DIRECTORY" ]; then
  echo "Error: The provided directory does not exist."
  exit 1
fi

# Specify the file where checked videos are logged.
CHECKED_FILES="checked_files.txt"
touch $CHECKED_FILES

# Function to process each file.
process_file() {
  FILE="$1"
  
  # Check if the file was already processed.
  if grep -Fxq "$FILE" $CHECKED_FILES; then
    echo "File $FILE has already been checked."
    return
  fi

  echo "Checking video $FILE..."
  if ffmpeg -v error -i "$FILE" -f null - 2>&1 | grep -q "Invalid"; then
    echo "File $FILE is corrupted and will be repaired."
    if ffmpeg -y -i "$FILE" -c copy "repaired-$(basename "$FILE")"; then
      echo "File $FILE was successfully repaired."
    else
      echo "Error repairing $FILE."
    fi
  else
    echo "File $FILE is okay."
  fi

  # Locking mechanism for safe writing to the checked files list.
  (
    flock -x 200
    echo "$FILE" >> $CHECKED_FILES
  ) 200> ${CHECKED_FILES}.lock
}

# Export the function and necessary variables for parallel to use.
export -f process_file
export CHECKED_FILES

# Use GNU Parallel to process all video files concurrently.
find "$DIRECTORY" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" \) \
  | grep -v -F -f $CHECKED_FILES \
  | parallel -j $(nproc) process_file
  
