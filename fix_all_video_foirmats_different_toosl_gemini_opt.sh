#!/bin/bash

# --- Improved Tool Installation Check and Instructions ---
REQUIRED_TOOLS=(divfix++ ffmpeg mp4box) # Meteorite is GUI-only, HandBrakeCLI and vlc not directly used for repair in script
TOOL_INSTALL_INSTRUCTIONS=(
  "divfix++: sudo apt-get install divfix++ (Debian/Ubuntu) or brew install divfix++ (macOS)"
  "ffmpeg: sudo apt-get install ffmpeg (Debian/Ubuntu) or brew install ffmpeg (macOS)"
  "mp4box: sudo apt-get install gpac (Debian/Ubuntu) or brew install gpac (macOS)" # mp4box is part of gpac
  # "meteorite: GUI application - manual install required (if CLI version exists, instructions here)" # Meteorite GUI only
  # "HandBrakeCLI: sudo apt-get install handbrake-cli (Debian/Ubuntu) or brew install handbrake (macOS)" # HandBrakeCLI if needed later
  # "vlc: sudo apt-get install vlc (Debian/Ubuntu) or brew install vlc (macOS)" # VLC if needed later
)

MISSING_TOOLS=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo "Error: The following required tools are not installed:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "- $tool"
        for instruction in "${TOOL_INSTALL_INSTRUCTIONS[@]}"; do
            if [[ "$instruction" == *"$tool:"* ]]; then
                echo "  Install using: ${instruction#*: }"
                break
            fi
        done
    done
    echo "Please install them and try again."
    exit 1
fi
echo "All required tools are installed."

# --- Directory and Logging Setup ---
DIR="./videos"
OUTPUT_DIR="./repaired"
LOG_FILE="$OUTPUT_DIR/repair.log"
mkdir -p "$OUTPUT_DIR"
echo "$(date) - Script started" >> "$LOG_FILE" # Start logging

# --- Repair Functions ---
repair_avi() {
    local input_file="$1"
    local output_file="$OUTPUT_DIR/${input_file##*/}_fixed.avi"
    echo "$(date) - AVI Repair: Starting divfix++ for '$input_file'" >> "$LOG_FILE"
    divfix ++ "$input_file" -o "$output_file" 2>> "$LOG_FILE" # Log errors from divfix++
    if [[ $? -eq 0 ]]; then
        echo "$(date) - AVI Repair: Successfully repaired '$input_file' to '$output_file'" >> "$LOG_FILE"
        echo "AVI: Successfully repaired '$input_file'"
    else
        echo "$(date) - AVI Repair: divfix++ failed for '$input_file'. Check $LOG_FILE for errors." >> "$LOG_FILE"
        echo "AVI: Repair failed for '$input_file'. Check $LOG_FILE"
    fi
}

repair_mkv() {
    local input_file="$1"
    local output_file="$OUTPUT_DIR/${input_file##*/}_fixed.mkv"
    echo "$(date) - MKV Repair: Attempting ffmpeg based repair for '$input_file'" >> "$LOG_FILE"
    ffmpeg -err_detect ignore_err -i "$input_file" -c copy -map 0 -f matroska -y "$output_file" 2>> "$LOG_FILE" # Attempt ffmpeg repair for MKV
    if [[ $? -eq 0 ]]; then
        echo "$(date) - MKV Repair: ffmpeg repair successful for '$input_file' to '$output_file'" >> "$LOG_FILE"
        echo "MKV: ffmpeg repair successful for '$input_file'"
    else
        echo "$(date) - MKV Repair: ffmpeg repair failed for '$input_file'. Consider manual repair with mkvtoolnix-gui or Meteorite (GUI). Check $LOG_FILE for ffmpeg errors." >> "$LOG_FILE"
        echo "MKV: ffmpeg repair failed for '$input_file'. Consider manual repair (mkvtoolnix-gui/Meteorite)."
    fi
}

repair_mp4() {
    local input_file="$1"
    local output_file="$OUTPUT_DIR/${input_file##*/}_fixed.mp4"
    echo "$(date) - MP4 Repair: Starting MP4Box for '$input_file'" >> "$LOG_FILE"
    MP4Box -isma "$input_file" -out "$output_file" 2>> "$LOG_FILE" # Log errors from MP4Box
    if [[ $? -eq 0 ]]; then
        echo "$(date) - MP4 Repair: MP4Box repair successful for '$input_file' to '$output_file'" >> "$LOG_FILE"
        echo "MP4: MP4Box repair successful for '$input_file'"
    else
        echo "$(date) - MP4 Repair: MP4Box failed for '$input_file'. Check $LOG_FILE for errors." >> "$LOG_FILE"
        echo "MP4: MP4Box repair failed for '$input_file'. Check $LOG_FILE"
    fi
}

repair_general() {
    local input_file="$1"
    local output_file="$OUTPUT_DIR/${input_file##*/}_fixed.mkv" # Default to mkv for general repair
    echo "$(date) - General Repair: Starting ffmpeg for '$input_file'" >> "$LOG_FILE"
    ffmpeg -err_detect ignore_err -i "$input_file" -c:v copy -c:a copy -y "$output_file" 2>> "$LOG_FILE" # Log errors from ffmpeg
    if [[ $? -eq 0 ]]; then
        echo "$(date) - General Repair: ffmpeg repair successful for '$input_file' to '$output_file'" >> "$LOG_FILE"
        echo "General: ffmpeg repair successful for '$input_file'"
    else
        echo "$(date) - General Repair: ffmpeg repair failed for '$input_file'. Check $LOG_FILE for errors." >> "$LOG_FILE"
        echo "General: ffmpeg repair failed for '$input_file'. Check $LOG_FILE"
    fi
}

# --- Process File Function ---
process_file() {
    local file="$1"
    echo "Processing '$file'..."

    case "${file##*.}" in
        avi|AVI)
            echo "Using DivFix++ for AVI repair on '$file'."
            repair_avi "$file"
            ;;
        mkv|MKV)
            echo "Using ffmpeg for MKV repair attempt on '$file'."
            repair_mkv "$file"
            ;;
        mp4|MP4)
            echo "Using MP4Box for MP4 repair on '$file'."
            repair_mp4 "$file"
            ;;
        *)
            echo "Using ffmpeg for general repair on '$file'."
            repair_general "$file"
            ;;
    esac
    echo "Finished processing '$file'."
}

# --- Iterate over video files ---
find "$DIR" -type f -print0 | while IFS= read -r -d $'\0' file; do # Use -print0 and read -d $'\0' for filenames with any characters
    process_file "$file"
done

echo "$(date) - Script finished. Check '$LOG_FILE' for detailed logs." >> "$LOG_FILE" # End logging
echo "Script finished. Check '$LOG_FILE' for detailed logs."
