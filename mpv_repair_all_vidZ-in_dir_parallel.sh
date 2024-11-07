#!/bin/bash

# Ensure GNU Parallel is installed
if ! command -v parallel &> /dev/null; then
    echo "GNU Parallel is required but not installed. Please install it and try again."
    exit 1
fi

# Define video extensions
video_extensions=("*.mp4" "*.avi" "*.mov" "*.mkv" "*.flv" "*.wmv" "*.m4v" "*.mpg" "*.mpeg" "*.3gp" "*.webm")

# Function to check if a video file is playable with mpv
is_playable() {
    local file="$1"
    echo "Checking playability of: $file"
    if mpv --no-audio --frames=1 --vo=null "$file" &>/dev/null; then
        return 0
    else
        echo "Error: Playability issues detected in: $file"
        return 1
    fi
}

# Function to repair a video file using ffmpeg
repair_video() {
    local file="$1"
    local repaired_file="${file%.*}_repaired.${file##*.}"

    echo "Attempting to repair: $file"
    if ffmpeg -err_detect ignore_err -i "$file" -c:v copy -c:a copy -y "$repaired_file" 2>/dev/null; then
        mv -f "$repaired_file" "$file"
        echo "Successfully repaired and replaced: $file"
    else
        echo "Failed to repair: $file. Removing temporary files."
        rm -f "$repaired_file"
    fi
}

export -f is_playable
export -f repair_video

# Process video files using GNU Parallel
echo "Starting video integrity check and repair process..."
for ext in "${video_extensions[@]}"; do
    echo "Searching for files with extension: $ext"
    find . -type f -iname "$ext" -print0 | parallel -0 -j$(nproc) --no-notice bash -c '
        file="$0"
        if [ -z "$file" ]; then
            echo "File is empty or not provided."
            exit 1
        fi
        echo "Processing file: $file"
        if ! is_playable "$file"; then
            repair_video "$file"
        else
            echo "No issues detected in: $file. It is playable."
        fi
    ' -- {}
done
echo "Video check and repair process completed."
