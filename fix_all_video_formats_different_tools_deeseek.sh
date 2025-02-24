#!/bin/bash
set -euo pipefail

# Configuration
DIR="./videos"
OUTPUT_DIR="./repaired"
LOG_FILE="./video_repair.log"
MAX_PARALLEL_JOBS=$(nproc)
TEMPDIR=$(mktemp -d)

# Cleanup function
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "$TEMPDIR"
}
trap cleanup EXIT ERR

# Initialize logging
exec 3> >(tee -a "$LOG_FILE")
log() {
    printf "[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee >(cat >&3)
}

# Verify dependencies
declare -A REQUIRED_TOOLS=(
    [ffmpeg]="ffmpeg"
    [MP4Box]="gpac"
    [divfix]="divfix"
    [mkvmerge]="mkvtoolnix"
)

check_dependencies() {
    for cmd in "${!REQUIRED_TOOLS[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR: Missing required tool: $cmd (install ${REQUIRED_TOOLS[$cmd]})"
            return 1
        fi
    done
}

# Repair functions
repair_avi() {
    local input="$1"
    local output="$2"
    log "Repairing AVI: $input"
    if ! divfix ++ "$input" -o "$output"; then
        log "DivFix++ failed, trying ffmpeg fallback..."
        ffmpeg -err_detect ignore_err -i "$input" -c:v copy -c:a copy -y "${output%.avi}.mkv"
    fi
}

repair_mkv() {
    local input="$1"
    local output="$2"
    log "Repairing MKV: $input"
    if ! mkvmerge -o "$output" "$input"; then
        log "mkvmerge failed, trying ffmpeg remux..."
        ffmpeg -err_detect ignore_err -i "$input" -c:v copy -c:a copy -map_metadata 0 -y "$output"
    fi
}

repair_mp4() {
    local input="$1"
    local output="$2"
    log "Repairing MP4: $input"
    if ! MP4Box -isma "$input" -out "$output"; then
        log "MP4Box failed, trying ffmpeg fallback..."
        ffmpeg -err_detect ignore_err -i "$input" -c:v copy -c:a copy -movflags faststart -y "$output"
    fi
}

process_file() {
    local input="$1"
    local base="${input##*/}"
    local ext="${base##*.}"
    local temp_output="${TEMPDIR}/${base%.*}_temp.${ext}"
    local final_output="${OUTPUT_DIR}/${base%.*}_repaired.${ext}"

    case "${ext,,}" in
        avi) repair_avi "$input" "$temp_output" ;;
        mkv) repair_mkv "$input" "$temp_output" ;;
        mp4) repair_mp4 "$input" "$temp_output" ;;
        *) 
            log "Unsupported format: $ext, attempting general repair"
            ffmpeg -err_detect ignore_err -i "$input" -c:v copy -c:a copy -y "${temp_output%.*}.mkv"
            ;;
    esac

    if [ -f "$temp_output" ]; then
        mv "$temp_output" "$final_output"
        log "Successfully repaired: $final_output"
    else
        log "ERROR: Failed to repair $input"
    fi
}

# Main execution
main() {
    check_dependencies || exit 1
    mkdir -p "$OUTPUT_DIR"
    log "Starting video repair process"
    
    # Process files in parallel
    find "$DIR" -type \( -iname '*.avi' -o -iname '*.mkv' -o -iname '*.mp4' \) -print0 \
        | xargs -0 -P "$MAX_PARALLEL_JOBS" -I {} bash -c '
            process_file "$1" 2>&1 | sed "s/^/[\$(date +%H:%M:%S)] [PID $$] /" >> "$2"
        ' _ {} "$LOG_FILE"

    log "Processing complete. Results saved to: $OUTPUT_DIR"
}

main
