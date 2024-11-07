#!/bin/bash

# Define video extensions
video_extensions=("*.mp4" "*.avi" "*.mov" "*.mkv" "*.flv" "*.wmv" "*.m4v" "*.mpg" "*.mpeg" "*.3gp" "*.webm")

# Function to check if a video file is playable with mpv
is_playable() {
    echo "Checking playability of: $1"
    if mpv --no-audio --frames=1 --vo=null "$1" &>/dev/null; then
        return 0
    else
        echo "Error: Playability issues detected in: $1"
        return 1
    fi
}

# Function to repair a video file using ffmpeg
repair_video() {
    local file="$1"
    local repaired_file="${file%.*}_repaired.${file##*.}"

    echo "Attempting to repair: $file"
    if ffmpeg -err_detect ignore_err -i "$file" -c:v copy -c:a copy -y "$repaired_file" 2>/dev/null; then
        mv -f "$repaired_file" "$file"  # Replace original file with repaired file
        echo "Successfully repaired and replaced: $file"
    else
        echo "Failed to repair: $file. Removing temporary files."
        rm -f "$repaired_file"
    fi
}

# Search for video files and check each one
echo "Starting video integrity check and repair process..."
for ext in "${video_extensions[@]}"; do
    echo "Searching for files with extension: $ext"
    find . -type f -iname "$ext" | while IFS= read -r file; do
        echo "Processing file: $file"
        if ! is_playable "$file"; then
            repair_video "$file"
        else
            echo "No issues detected in: $file. It is playable."
        fi
    done
done
echo "Video check and repair process completed."

