#!/bin/bash

# Enable multithreading and international character support
export LC_ALL=C.UTF-8

# Set higher process priority
renice -n -5 $$ >/dev/null 2>&1

# Optimize IO
ionice -c 1 -n 0 -p $$ >/dev/null 2>&1

# Smart repair function that first checks if repair is needed
smart_repair() {
    local file="$1"
    
    # Quick check if file is corrupt
    if ffmpeg -v error -i "$file" -f null - >/dev/null 2>&1; then
        echo -e "\033[1;34m•\033[0m OK: $file"
        return 0
    fi
    
    # File is corrupt, attempt repair
    local repairedfile="${file%.*}_repaired.${file##*.}"
    
    if ffmpeg -v error -threads 2 -err_detect ignore_err -i "$file" -c copy -y "$repairedfile" >/dev/null 2>&1; then
        # Verify the repaired file
        if ffmpeg -v error -i "$repairedfile" -f null - >/dev/null 2>&1; then
            mv -f "$repairedfile" "$file" && echo -e "\033[1;32m✓\033[0m Repaired: $file"
        else
            echo -e "\033[1;31m✗\033[0m Failed (output corrupt): $file"
            rm -f "$repairedfile" 2>/dev/null
        fi
    else
        echo -e "\033[1;31m✗\033[0m Failed (repair error): $file"
        rm -f "$repairedfile" 2>/dev/null
    fi
}

export -f smart_repair

echo "Starting optimized video repair process..."

# Find and process all video files with maximum parallelism
find . -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \
    -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.m4v" -o -iname "*.mpg" \
    -o -iname "*.mpeg" -o -iname "*.3gp" -o -iname "*.webm" \) -print0 | 
xargs -0 -P "$(nproc)" -n1 bash -c 'smart_repair "$1"' _

echo "Processing complete."
