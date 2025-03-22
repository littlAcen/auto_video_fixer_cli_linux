#!/bin/bash

# Enable parallel processing and handle special characters
export LC_ALL=C.UTF-8

# Ensure required tools are installed
if ! command -v ffmpeg &> /dev/null; then
    echo "FFmpeg is required but not installed. Please install it and try again."
    exit 1
fi

echo "Starting video repair process with $(nproc) processors..."

# Find all video files and process them in parallel
find . -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \
    -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.m4v" -o -iname "*.mpg" \
    -o -iname "*.mpeg" -o -iname "*.3gp" -o -iname "*.webm" \) -print0 | 
xargs -0 -P "$(nproc)" -I '{}' bash -c '
    file="$1"
    echo "Processing: $file"
    
    # Check file directly without prior verification to speed things up
    repairedfile="${file%.*}_repaired.${file##*.}"
    
    # Attempt repair with optimized settings
    if ffmpeg -v error -err_detect ignore_err -i "$file" -c copy -y "$repairedfile" 2>/dev/null; then
        # Check if the repair was successful by comparing file validity
        if ffmpeg -v error -i "$repairedfile" -f null - 2>/dev/null; then
            mv -f "$repairedfile" "$file"
            echo "✓ Repaired: $file"
        else
            echo "✗ Failed to repair: $file (output file also corrupt)"
            rm -f "$repairedfile"
        fi
    else
        echo "✗ Failed to repair: $file (repair process failed)"
        rm -f "$repairedfile" 2>/dev/null
    fi
' -- '{}'

echo "All video files processed."
