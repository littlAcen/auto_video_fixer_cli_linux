#!/bin/bash
set -euo pipefail  # Strikte Fehlerbehandlung

generate_install_instructions() {
    local instructions=""
    instructions+="# Installationsanweisungen für fehlende Tools:\n"
    instructions+="# ---------------------------------------\n"
    for tool_spec in "${REQUIRED_TOOLS[@]}"; do
        local tool=${tool_spec%%:*}
        local package=${tool_spec#*:}
        [[ "$tool" == "$package" ]] && package=$tool

        local ubuntu_command=""
        local macos_command=""

        case "$package" in
            "divfix++")
                ubuntu_command="sudo apt-get install divfix++"
                macos_command="brew install divfix++"
                ;;
            "ffmpeg")
                ubuntu_command="sudo apt-get install ffmpeg"
                macos_command="brew install ffmpeg"
                ;;
            "gpac") # mp4box package
                ubuntu_command="sudo apt-get install gpac"
                macos_command="brew install gpac"
                ;;
            "mplayer") # mencoder package
                ubuntu_command="sudo apt-get install mencoder" # Or mplayer package? check.
                macos_command="brew install mplayer" # or mencoder?
                ;;
            "handbrake-cli")
                ubuntu_command="sudo apt-get install handbrake-cli"
                macos_command="brew install handbrake"
                ;;
            "gstreamer1.0-tools")
                ubuntu_command="sudo apt-get install gstreamer1.0-tools"
                macos_command="brew install gstreamer"
                ;;
            "mlt")
                ubuntu_command="sudo apt-get install mlt"
                macos_command="brew install mlt"
                ;;
             *) # Default case or "avidemux3-cli" - adjust if needed for more specific avidemux instructions
                ubuntu_command="# Für ${package} spezifische Ubuntu Installation prüfen"
                macos_command="# Für ${package} spezifische macOS Installation prüfen"
                ;;
        esac

        instructions+="# ${tool}:\n"
        if [[ -n "$ubuntu_command" ]]; then
            instructions+="  # Ubuntu/Debian: ${ubuntu_command}\n"
        fi
        if [[ -n "$macos_command" ]]; then
            instructions+="  # macOS: ${macos_command}\n"
        fi
    done

    # --- Add Combined Installation Commands ---
    instructions+="\n"  # Add a newline for separation
    instructions+="# ---------------------------------------\n"
    instructions+="# ### Installiere alle Tools zusammen:\n"
    instructions+="# Ubuntu/Debian Befehl:\n"
    instructions+="# sudo apt-get update && sudo apt-get install -y divfix++ ffmpeg gpac mencoder handbrake-cli gstreamer1.0-tools avidemux3-cli mlt\n"
    instructions+="# macOS Befehl:\n"
    instructions+="# brew install divfix++ ffmpeg gpac mplayer handbrake gstreamer avidemux mlt\n"
    instructions+="# ---------------------------------------\n"


    return 0 # Function itself always succeeds, returns instructions string via stdout
}

# --- Script Description ---
# Video-Reparatur-Script mit erweiterten Sicherheits- und Fehlerbehandlungsfunktionen
# Verwendet verschiedene Tools zur Reparatur beschädigter Videodateien
# Version: 1.0

# --- Globale Variablen ---
readonly DIR="./videos"
readonly OUTPUT_DIR="./repaired"
readonly LOG_DIR="./logs"
readonly LOG_FILE="${LOG_DIR}/repair.log"
readonly MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB
readonly TEMP_DIR="/tmp/video_repair_$$"
declare -A REPAIR_ATTEMPTS

# --- Required Tools ---
readonly REQUIRED_TOOLS=(
    "ffmpeg"
    "mp4box:gpac"
    "mencoder:mplayer"
    "handbrakecli:handbrake-cli"
    "gst-launch-1.0:gstreamer1.0-tools"
    "melt:mlt"
)

# --- Hilfsfunktionen ---
setup_logging() {
    mkdir -p "$LOG_DIR"
    if [[ -f "$LOG_FILE" && $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
    fi
    exec 3>&1 4>&2
    exec 1> >(tee -a "$LOG_FILE") 2>&1
}

log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*"
}

cleanup() {
    local exit_code=$?
    log "INFO" "Aufräumen temporärer Dateien..."
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    exec 1>&3 2>&4
    exit $exit_code
}

check_requirements() {
    local missing_tools=()

    for tool_spec in "${REQUIRED_TOOLS[@]}"; do
        local tool=${tool_spec%%:*}
        local package=${tool_spec#*:}
        [[ "$tool" == "$package" ]] && package=$tool

        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$package")
        fi
    done

    if (( ${#missing_tools[@]} > 0 )); then
        log "ERROR" "Fehlende Tools: ${missing_tools[*]}"
        log "INFO" "Installation auf Ubuntu/Debian:"
        log "INFO" "sudo apt-get update && sudo apt-get install -y ${missing_tools[*]}"
        log "INFO" "Installation auf macOS:"
        log "INFO" "brew install ${missing_tools[*]}"
        return 1
    fi

    return 0
}

validate_file() {
    local file=$1
    if [[ ! -f "$file" ]]; then
        log "ERROR" "Datei nicht gefunden: $file"
        return 1
    fi
    if [[ ! -r "$file" ]]; then
        log "ERROR" "Keine Leserechte für: $file"
        return 1
    fi
    return 0
}

ensure_space() {
    local file=$1
    local required_space=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
    local available_space=$(df -P "$OUTPUT_DIR" | awk 'NR==2 {print $4*1024}')

    if (( required_space * 2 > available_space )); then
        log "ERROR" "Nicht genügend Speicherplatz verfügbar"
        return 1
    fi
    return 0
}

# --- Reparaturfunktionen ---
repair_mp4() {
    local input_file=$1
    local output_file="${OUTPUT_DIR}/$(basename "${input_file%.*}")_fixed.mp4"
    local temp_file="${TEMP_DIR}/$(basename "${input_file%.*}")_temp.mp4"

    log "INFO" "Starte MP4-Reparatur: $input_file"

    mkdir -p "$TEMP_DIR"

    # Versuch 1: MP4Box
    if MP4Box -inter 500 "$input_file" -out "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$output_file"
        log "SUCCESS" "MP4-Reparatur erfolgreich: $output_file"
        return 0
    fi

    # Versuch 2: FFmpeg
    if ffmpeg -err_detect ignore_err -i "$input_file" -c copy -movflags +faststart "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$output_file"
        log "SUCCESS" "MP4-Reparatur mit FFmpeg erfolgreich: $output_file"
        return 0
    fi

    log "ERROR" "MP4-Reparatur fehlgeschlagen: $input_file"
    return 1
}

repair_mkv() {
    local input_file=$1
    local output_file="${OUTPUT_DIR}/$(basename "${input_file%.*}")_fixed.mkv"

    log "INFO" "Starte MKV-Reparatur: $input_file"

    if ffmpeg -err_detect ignore_err -i "$input_file" -c copy -map 0 "$output_file" 2>/dev/null; then
        log "SUCCESS" "MKV-Reparatur erfolgreich: $output_file"
        return 0
    fi

    log "ERROR" "MKV-Reparatur fehlgeschlagen: $input_file"
    return 1
}

repair_general() {
    local input_file=$1
    local output_file="${OUTPUT_DIR}/$(basename "${input_file%.*}")_fixed.mkv"
    local temp_file="${TEMP_DIR}/$(basename "${input_file%.*}")_temp"

    log "INFO" "Starte allgemeine Reparatur: $input_file"

    mkdir -p "$TEMP_DIR"

    # Versuch 1: FFmpeg
    if ffmpeg -err_detect ignore_err -i "$input_file" -c copy "${temp_file}.mkv" 2>/dev/null; then
        mv "${temp_file}.mkv" "$output_file"
        log "SUCCESS" "Allgemeine Reparatur erfolgreich: $output_file"
        return 0
    fi

    # Versuch 2: Handbrake
    if HandBrakeCLI -i "$input_file" -o "${temp_file}.mp4" --preset="Fast 1080p30" 2>/dev/null; then
        mv "${temp_file}.mp4" "$output_file"
        log "SUCCESS" "Reparatur mit Handbrake erfolgreich: $output_file"
        return 0
    fi

    log "ERROR" "Allgemeine Reparatur fehlgeschlagen: $input_file"
    return 1
}

# --- Hauptprogramm ---
main() {
    trap cleanup EXIT

    log "INFO" "Starte Video-Reparatur-Script"

    setup_logging
    check_requirements || exit 1

    mkdir -p "$OUTPUT_DIR" "$TEMP_DIR"

    if [[ ! -d "$DIR" ]]; then
        log "ERROR" "Videoverzeichnis nicht gefunden: $DIR"
        exit 1
    fi

    local count=0
    local total=$(find "$DIR" -type f -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" | wc -l)

    while IFS= read -r -d '' file; do
        ((count++))
        log "INFO" "Verarbeite Datei $count von $total: $file"

        validate_file "$file" || continue
        ensure_space "$file" || continue

        case "${file,,}" in
            *.mp4) repair_mp4 "$file" ;;
            *.mkv) repair_mkv "$file" ;;
            *) repair_general "$file" ;;
        esac
    done < <(find "$DIR" -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" \) -print0)

    log "INFO" "Verarbeitung abgeschlossen. Reparierte Dateien in: $OUTPUT_DIR"
}

main "$@"
