#!/bin/bash

# Set locale for UTF-8
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Validate input and ensure exactly one argument (directory)
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

DIRECTORY="$(realpath "$1")"
echo "Debug: Working with directory: $DIRECTORY"

# Check if the directory exists
if [ ! -d "$DIRECTORY" ]; then
  echo "Error: Directory does not exist: $DIRECTORY"
  exit 1
fi

# Set and ensure the checked files tracker is valid
CHECKED_FILES="$DIRECTORY/checked_files.txt"
touch "$CHECKED_FILES"
echo "Debug: Using checked files list: $CHECKED_FILES"

repair_file() {
  local input_file="$1"
  
  # Ensure the input_file is valid and available
  local filename
  filename=$(basename "$input_file")
  echo "Debug: Processing Input file $input_file, Filename: $filename"

  if [ ! -f "$input_file" ]; then
    echo "Error: input_file does not exist: $input_file"
    return
  fi

  # Check if this filename was already processed using awk
  if [ -n "$filename" ] && awk -v f="$filename" '$0 == f { exit 0 } END { exit 1 }' "$CHECKED_FILES"; then
    echo "Already checked: $filename"
    return
  fi

  echo "Inspecting: $input_file"

  local base="${input_file%.*}"
  local extension="${input_file##*.}"
  local repaired_file="${base}_repaired.${extension}"
  echo "Debug: Base: $base, Extension: $extension, Repaired file: $repaired_file"

  # Use ffmpeg to check for errors
  ffmpeg -v error -i "$input_file" -f null - 2>/tmp/error.log

  if [ -s /tmp/error.log ]; then
    echo "Found errors in \"$input_file\", attempting repair..."

    if [[ "$extension" == "mp4" ]]; then
      echo "Debug: Running mp4fragment on $input_file"
      mp4fragment "$input_file" "$repaired_file"
    else
      echo "Debug: Running ffmpeg to copy streams for $input_file"
      ffmpeg -err_detect ignore_err -i "$input_file" -c:v copy -c:a copy -y "$repaired_file" > /dev/null
    fi

    if [ -f "$repaired_file" ]; then
      echo "Debug: Moving $repaired_file to $input_file"
      mv "$repaired_file" "$input_file"
      echo "Successfully repaired: \"$input_file\""
    else
      echo "Failed to repair: \"$input_file\""
      rm -f "$repaired_file"
    fi
  else
    echo "No errors detected in \"$input_file\""
  fi

  # Record the filename as checked
  if [ -n "$filename" ]; then
    echo "Debug: Adding $filename to $CHECKED_FILES"
    echo "$filename" >> "$CHECKED_FILES"
  fi

  # Clean up
  rm -f /tmp/error.log
}

export -f repair_file

# Execute repair_file for each video file
find "$DIRECTORY" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \) -print0 | \
xargs -0 -I {} bash -c "repair_file \"\$(realpath '{}')\"" _

echo "File processing complete."