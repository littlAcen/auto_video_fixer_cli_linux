#!/bin/bash

# Ensure all necessary tools are installed
REQUIRED_TOOLS=(vlc HandBrakeCLI ffmpeg mp4box divfix meteorite)
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $tool &> /dev/null; then
        echo "Required tool $tool is not installed. Please install it and try again."
        exit 1
    fi
done

# Directory of input video files
DIR="./videos"

# Output directory for repaired files
OUTPUT_DIR="./repaired"
mkdir -p "$OUTPUT_DIR"

repair_avi() {
    local input_file="$1"
    local output_file="$OUTPUT_DIR/${input_file##*/}_fixed.avi"
    divfix ++ "$input_file" -o "$output_file"
}

repair_mkv() {
    local input_file="$1"
    # Assuming Meteorite would be used if it had a CLI equivalent
    # Currently, this is a placeholder as Meteorite is GUI-only
    echo "Meteorite is GUI based. Please run it manually for $input_file."
}

repair_mp4() {
    local input_file="$1"
    local output_file="$OUTPUT_DIR/${input_file##*/}_fixed.mp4"
    MP4Box -isma "$input_file" -out "$output_file"
}

repair_general() {
    local input_file="$1"
    local output_file="$OUTPUT_DIR/${input_file##*/}_fixed.mkv"
    ffmpeg -err_detect ignore_err -i "$input_file" -c:v copy -c:a copy -y "$output_file"
}

process_file() {
    local file="$1"
    echo "Processing $file..."

    case "${file##*.}" in
        avi)
            echo "Using DivFix++ for AVI repair."
            repair_avi "$file"
            ;;
        mkv)
            echo "Using Meteorite for MKV repair."
            repair_mkv "$file"
            ;;
        mp4)
            echo "Using MP4Box for MP4 repair."
            repair_mp4 "$file"
            ;;
        *)
            echo "Using ffmpeg for general repair."
            repair_general "$file"
            ;;
    esac
}

# Iterate over each video file in the directory
find "$DIR" -type f | while IFS= read -r file; do
    process_file "$file"
done

