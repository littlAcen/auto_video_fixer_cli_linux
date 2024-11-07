#!/bin/bash

# Ensure GNU Parallel is installed
if ! command -v parallel &> /dev/null; then
    echo "GNU Parallel is required but not installed. Please install it and try again."
    exit 1
fi

# Find and process each video file using parallel
find . -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.m4v" -o -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.3gp" -o -iname "*.webm" \) -print0 | parallel -0 -j$(nproc) --no-notice bash -c '
file="$1"
if [ -z "$file" ]; then
  echo "File is empty or not provided."
  exit 1
fi
echo "Checking file: \"$file\""

# Verify if the video file is potentially corrupt
if ! ffmpeg -v error -i "$file" -f null - 2>/dev/null; then
    echo "Found errors in \"$file\", attempting repair..."
    repairedfile="${file%.*}_repaired.${file##*.}"

    # Attempt to repair the file
    if ffmpeg -err_detect ignore_err -i "$file" -c:v copy -c:a copy -y "$repairedfile" 2>/dev/null; then
        mv -f "$repairedfile" "$file" # Replace the original file with the repaired file
        echo "Successfully repaired and replaced: \"$file\""
    else
        echo "Failed to repair file: \"$file\""
        rm -f -- "$repairedfile"
    fi
else
    echo "No errors detected in \"$file\""
fi
' -- {}

