#!/bin/bash

# Enable multithreading and international character support
export LC_ALL=C.UTF-8

# Set higher process priority
renice -n -5 $$ >/dev/null 2>&1

# Optimize IO
ionice -c 1 -n 0 -p $$ >/dev/null 2>&1

# Increase open file limits
ulimit -n 4096 2>/dev/null

# Configure ffmpeg for faster processing
export FFREPORT=level=32

# Custom ffmpeg repair function with optimized parameters
quick_repair() {
    local input="$1"
    local output="${input%.*}_repaired.${input##*.}"
    
    # Use faster copy codec options and minimal error checking
    if ffmpeg -hide_banner -loglevel fatal -threads 2 -err_detect ignore_err \
        -i "$input" -c copy -map 0 -y "$output" >/dev/null 2>&1; then
        mv -f "$output" "$input" >/dev/null 2>&1 && echo -e "\033[1;32m✓\033[0m Repaired: $input"
    else
        rm -f "$output" >/dev/null 2>&1
        echo -e "\033[1;31m✗\033[0m Failed: $input"
    fi
}

export -f quick_repair

echo "Starting ultra-fast video repair process..."

# Find and process all video files with maximum parallelism
find . -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \
    -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.m4v" -o -iname "*.mpg" \
    -o -iname "*.mpeg" -o -iname "*.3gp" -o -iname "*.webm" \) -print0 | 
xargs -0 -P "$(nproc)" -n1 bash -c 'quick_repair "$1"' _ 

echo "Processing complete."
