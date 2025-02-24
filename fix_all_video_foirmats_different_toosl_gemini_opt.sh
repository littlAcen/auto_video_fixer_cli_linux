#!/bin/bash

# --- Script Description ---  <-- Script Description Block STARTS HERE - MUST BE AT THE VERY BEGINNING
# This script attempts to repair corrupted video files using a variety of tools.
# It checks for required tools, processes video files in the './videos' directory,
# and saves repaired files to the './repaired' directory.
# Detailed logs are saved in './repaired/repair.log'.
#
# Script finished. Check '$LOG_FILE' for detailed logs.
#
# One-line installation of required tools (Debian/Ubuntu):
# sudo apt-get update && sudo apt-get install -y divfix++ ffmpeg gpac mencoder handbrake-cli gstreamer1.0-tools avidemux3-cli mlt
#
# One-line installation of required tools (macOS using Homebrew):
# brew install divfix++ ffmpeg gpac mplayer handbrake gstreamer avidemux mlt
#
# Note: These are example commands. Package names or installation methods might vary
#       depending on your specific operating system and package manager.
#       It's recommended to install tools individually and check for errors if the
#       one-liner fails. See script comments or documentation for details.
# --- Script Description ---  <-- Script Description Block ENDS HERE

# --- Improved Tool Installation Check and Instructions ---
REQUIRED_TOOLS=(divfix++ ffmpeg mp4box mencoder handbrakecli gst-launch-1.0 avidemux_cli melt) # Added gstreamer, avidemux, melt
TOOL_INSTALL_INSTRUCTIONS=(
  "divfix++: sudo apt-get install divfix++ (Debian/Ubuntu) or brew install divfix++ (macOS)"
  "ffmpeg: sudo apt-get install ffmpeg (Debian/Ubuntu) or brew install ffmpeg (macOS)"
  "mp4box: sudo apt-get install gpac (Debian/Ubuntu) or brew install gpac (macOS)" # mp4box is part of gpac
  "mencoder: sudo apt-get install mencoder (Debian/Ubuntu) or brew install mencoder (macOS - via mplayer)" # mencoder install instructions
  "handbrakecli: sudo apt-get install handbrake-cli (Debian/Ubuntu) or brew install handbrake (macOS)" # handbrakecli install instructions
  "gst-launch-1.0: sudo apt-get install gstreamer1.0-tools (Debian/Ubuntu) or brew install gstreamer (macOS)" # gstreamer install instructions
  "avidemux_cli: sudo apt-get install avidemux3-cli (Debian/Ubuntu) or brew install avidemux (macOS - may need to build from source for CLI)" # avidemux install instructions - macOS might be more complex
  "melt: sudo apt-get install mlt (Debian/Ubuntu) or brew install mlt (macOS)" # mlt install instructions
  "### Install all tools together with:",  # String literal for the heading
  "# Debian/Ubuntu Command: sudo apt-get update && sudo apt-get install -y divfix++ ffmpeg gpac mencoder handbrake-cli gstreamer1.0-tools avidemux3-cli mlt", # String literal with comment marker
  "# MacOS: brew install divfix++ ffmpeg gpac mplayer handbrake gstreamer avidemux mlt" # String literal with comment marker
) # Tool Installation Block ENDS HERE

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
                echo "  Install using: ${instruction#*: }"
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

repair_general() { # General repair function trying multiple tools
    local input_file="$1"
    local output_file="$OUTPUT_DIR/${input_file##*/}_fixed.mkv" # Default output to MKV for general repair
    local temp_output="${input_file}.repair_temp.mp4" # Temp file for tools that might require it

    # 1. ffmpeg (Remux and error detection)
    echo "$(date) - General Repair: Attempting ffmpeg remux..." >> "$LOG_FILE"
    if ffmpeg -err_detect ignore_err -i "$input_file" -c copy -y "$temp_output" 2>>"$LOG_FILE"; then
        if [[ -s "$temp_output" ]]; then
            mv "$temp_output" "$output_file"
            echo "$(date) - General Repair: ffmpeg remux successful." >> "$LOG_FILE"
            echo "General: ffmpeg remux successful."
            # return 0  <-- REMOVED return 0 here
        fi
    fi

    # 2. mencoder (Index fixing)
    echo "$(date) - General Repair: ffmpeg remux failed, trying mencoder..." >> "$LOG_FILE"
    if command -v mencoder &>/dev/null; then
        rm -f "$temp_output" # Cleanup temp file
        if mencoder "$input_file" -ovc copy -oac copy -o "$temp_output" 2>>"$LOG_FILE"; then
            if [[ -s "$temp_output" ]]; then
                mv "$temp_output" "$output_file"
                echo "$(date) - General Repair: mencoder repair successful." >> "$LOG_FILE"
                echo "General: mencoder repair successful."
                # return 0  <-- REMOVED return 0 here
            fi
        fi
    fi

    # 3. MP4Box (For potential MP4 container issues - though general, might help)
    echo "$(date) - General Repair: mencoder failed, trying MP4Box -isma (MP4 container fix)..." >> "$LOG_FILE"
    local mp4box_temp_output="${input_file}.mp4box_temp.mp4" # Separate temp for MP4Box to avoid conflicts
    if MP4Box -isma "$input_file" -out "$mp4box_temp_output" 2>> "$LOG_FILE"; then
        if [[ -s "$mp4box_temp_output" ]]; then
            mv "$mp4box_temp_output" "$output_file"
            echo "$(date) - General Repair: MP4Box repair successful." >> "$LOG_FILE"
            echo "General: MP4Box repair successful."
            # return 0  <-- REMOVED return 0 here
        fi
    fi
    rm -f "$mp4box_temp_output" # Cleanup MP4Box temp file

    # 4. HandBrakeCLI (Remuxing/re-encoding as fallback - using fast preset)
    echo "$(date) - General Repair: MP4Box failed, trying HandBrakeCLI (remux/re-encode)..." >> "$LOG_FILE"
    if command -v HandBrakeCLI &>/dev/null; then
        rm -f "$temp_output" # Cleanup temp file
        if HandBrakeCLI -i "$input_file" -o "$temp_output" --preset="Fast 1080p30" 2>>"$LOG_FILE"; then # Fast preset for speed
            if [[ -s "$temp_output" ]]; then
                mv "$temp_output" "$output_file"
                echo "$(date) - General Repair: HandBrakeCLI repair successful." >> "$LOG_FILE"
                echo "General: HandBrakeCLI repair successful."
                # return 0  <-- REMOVED return 0 here
            fi
        fi
    fi

    # 5. Avidemux CLI (Copy mode - potential container/stream fix - might be format specific)
    echo "$(date) - General Repair: HandBrakeCLI failed, trying Avidemux CLI (copy mode)..." >> "$LOG_FILE"
    local avidemux_temp_output="${input_file}.avidemux_temp.${output_file##*.}" # Match output extension to final output
    if avidemux_cli --force-alt-h264 --load "$input_file" --video-codec copy --audio-codec copy --muxer mkv --output-file "$avidemux_temp_output" --run quit 2>>"$LOG_FILE"; then # Example: MKV output, adjust muxer as needed
        if [[ -s "$avidemux_temp_output" ]]; then
            mv "$avidemux_temp_output" "$output_file"
            echo "$(date) - General Repair: Avidemux CLI repair successful." >> "$LOG_FILE"
            echo "General: Avidemux CLI repair successful."
            # return 0  <-- REMOVED return 0 here
        fi
        fi
    fi
    rm -f "$avidemux_temp_output" # Cleanup Avidemux temp file


    # 6. GStreamer (Attempting a basic decode and encode pipeline - very general, might be slow/resource intensive)
    echo "$(date) - General Repair: Avidemux CLI failed, trying GStreamer (basic pipeline)..." >> "$LOG_FILE"
    local gst_temp_output="${input_file}.gst_temp.${output_file##*.}" # Match output extension
    if gst-launch-1.0 filesrc location="$input_file" ! decodebin ! filesink location="$gst_temp_output" 2>>"$LOG_FILE"; then # Very basic pipeline - adjust pipeline for more control if needed
        if [[ -s "$gst_temp_output" ]]; then
            mv "$gst_temp_output" "$output_file"
            echo "$(date) - General Repair: GStreamer repair successful." >> "$LOG_FILE"
            echo "General: GStreamer repair successful."
            # return 0  <-- REMOVED return 0 here
        fi
        fi
    fi
    rm -f "$gst_temp_output" # Cleanup GStreamer temp file


    # 7. MLT (melt) -  Basic remuxing attempt. MLT is more complex, basic use here. Might require more sophisticated MLT pipelines for advanced repair.
    echo "$(date) - General Repair: GStreamer failed, trying MLT (melt - basic remux)..." >> "$LOG_FILE"
    local melt_temp_output="${input_file}.melt_temp.${output_file##*.}" # Match output extension
    if melt "$input_file" -consumer avformat:\"$melt_temp_output\" 2>>"$LOG_FILE"; then # Basic melt command, adjust consumer and format if needed
        if [[ -s "$melt_temp_output" ]]; then
            mv "$melt_temp_output" "$output_file"
            echo "$(date) - General Repair: MLT (melt) repair successful." >> "$LOG_FILE"
            echo "General: MLT (melt) repair successful."
            # return 0  <-- REMOVED return 0 here
        fi
    fi
    rm -f "$melt_temp_output" # Cleanup MLT temp file


    # Final failure message if all attempts fail
    rm -f "$temp_output" # Cleanup any remaining temp files
    rm -f "$mp4box_temp_output"
    rm -f "$avidemux_temp_output"
    rm -f "$gst_temp_output"
    rm -f "$melt_temp_output"

    echo "$(date) - General Repair: All repair attempts failed for '$input_file'." >> "$LOG_FILE"
    echo "General: All repair attempts failed for '$input_file'."
    return 1 # Failure
}


# --- Process File Function --- (No changes needed here)
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
            echo "Using general repair (ffmpeg, mencoder, MP4Box, HandBrakeCLI, Avidemux CLI, GStreamer, MLT) for '$file'."
            repair_general "$file" # Call the combined repair function for other types
            ;;
    esac
    echo "Finished processing '$file'."
}

# --- Iterate over video files --- (No changes needed here)
find "$DIR" -type f -print0 | while IFS= read -r -d $'\0' file; do # Use -print0 and read -d $'\0' for filenames with any characters
    process_file "$file"
done

echo "$(date) - Script finished. Check '$LOG_FILE' for detailed logs." >> "$LOG_FILE" # End logging
echo "Script finished. Check '$LOG_FILE' for detailed logs."
