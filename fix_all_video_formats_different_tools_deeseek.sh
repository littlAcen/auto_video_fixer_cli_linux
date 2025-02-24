#!/bin/bash
set -euo pipefail

# --- Globale Konfiguration ---
readonly DIR="./videos"
readonly OUTPUT_DIR="./repaired"
readonly LOG_DIR="./logs"
readonly LOG_FILE="${LOG_DIR}/repair.log"
readonly MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB
readonly TEMP_DIR=$(mktemp -d)
declare -A REQUIRED_TOOLS=(
    [ffmpeg]="ffmpeg"
    [MP4Box]="gpac"
    [mencoder]="mplayer"
    [HandBrakeCLI]="handbrake-cli"
    [gst-launch-1.0]="gstreamer1.0-tools"
    [melt]="mlt"
)

# --- Hilfsfunktionen ---
setup_logging() {
    mkdir -p "$LOG_DIR"
    if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE" 2>/dev/null) -gt $MAX_LOG_SIZE ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
    fi
    exec 3>&1 4>&2
    exec > >(tee -a "$LOG_FILE") 2>&1
}

log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*"
}

cleanup() {
    local exit_code=$?
    log "INFO" "Aufräumen temporärer Dateien..."
    rm -rf "$TEMP_DIR"
    exec 1>&3 2>&4
    exit $exit_code
}

check_requirements() {
    local missing=()
    for cmd in "${!REQUIRED_TOOLS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("${REQUIRED_TOOLS[$cmd]}")
        fi
    done

    if ((${#missing[@]} > 0)); then
        log "ERROR" "Fehlende Pakete: ${missing[*]}"
        log "INFO" "Installationsbefehle:"
        log "INFO" "  Ubuntu/Debian: sudo apt-get install ${missing[*]}"
        log "INFO" "  macOS: brew install ${missing[*]}"
        return 1
    fi
    return 0
}

validate_file() {
    local file=$1
    [[ -f "$file" ]] || { log "ERROR" "Datei nicht gefunden: $file"; return 1; }
    [[ -r "$file" ]] || { log "ERROR" "Keine Leserechte: $file"; return 1; }
    return 0
}

ensure_space() {
    local file=$1
    local required=$(($(stat -c%s "$file") * 2))
    local available=$(df -P "$OUTPUT_DIR" | awk 'NR==2 {print $4 * 1024}')
    ((required > available)) && { log "ERROR" "Zu wenig Speicherplatz"; return 1; }
    return 0
}

# --- Reparaturfunktionen ---
repair_mp4() {
    local input=$1 output="${OUTPUT_DIR}/$(basename "${1%.*}")_fixed.mp4"
    log "INFO" "Starte MP4-Reparatur: $input"

    if MP4Box -isma "$input" -out "$output.tmp" 2>>"$LOG_FILE"; then
        mv "$output.tmp" "$output"
        log "SUCCESS" "Erfolgreich repariert: $output"
        return 0
    fi

    log "WARN" "MP4Box fehlgeschlagen, versuche FFmpeg"
    if ffmpeg -err_detect ignore_err -i "$input" -c copy -movflags +faststart "$output.tmp" 2>>"$LOG_FILE"; then
        mv "$output.tmp" "$output"
        log "SUCCESS" "Erfolgreich mit FFmpeg: $output"
        return 0
    fi

    rm -f "$output.tmp"
    log "ERROR" "MP4-Reparatur fehlgeschlagen"
    return 1
}

repair_mkv() {
    local input=$1 output="${OUTPUT_DIR}/$(basename "${1%.*}")_fixed.mkv"
    log "INFO" "Starte MKV-Reparatur: $input"

    if ffmpeg -err_detect ignore_err -i "$input" -c copy -map 0 "$output.tmp" 2>>"$LOG_FILE"; then
        mv "$output.tmp" "$output"
        log "SUCCESS" "Erfolgreich repariert: $output"
        return 0
    fi

    rm -f "$output.tmp"
    log "ERROR" "MKV-Reparatur fehlgeschlagen"
    return 1
}

repair_general() {
    local input=$1 output="${OUTPUT_DIR}/$(basename "${1%.*}")_fixed.mkv"
    log "INFO" "Starte allgemeine Reparatur: $input"

    if ffmpeg -err_detect ignore_err -i "$input" -c copy "$output.tmp" 2>>"$LOG_FILE"; then
        mv "$output.tmp" "$output"
        log "SUCCESS" "Erfolgreich repariert: $output"
        return 0
    fi

    log "WARN" "FFmpeg fehlgeschlagen, versuche HandBrake"
    if HandBrakeCLI -i "$input" -o "$output" --preset="Fast 1080p30" 2>>"$LOG_FILE"; then
        log "SUCCESS" "Erfolgreich mit HandBrake: $output"
        return 0
    fi

    rm -f "$output.tmp"
    log "ERROR" "Allgemeine Reparatur fehlgeschlagen"
    return 1
}

# --- Hauptprogramm ---
main() {
    trap cleanup EXIT INT TERM
    log "INFO" "Starte Video-Reparatur"
    setup_logging
    check_requirements || exit 1

    mkdir -p "$OUTPUT_DIR"
    [[ -d "$DIR" ]] || { log "ERROR" "Verzeichnis nicht gefunden: $DIR"; exit 1; }

    local count=0 total=$(find "$DIR" -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' \) -printf '.' | wc -c)
    
    while IFS= read -r -d $'\0' file; do
        ((count++))
        log "PROGRESS" "Verarbeite Datei $count/$total: ${file##*/}"
        
        validate_file "$file" || continue
        ensure_space "$file" || continue

        case "${file##*.}" in
            mp4|MP4) repair_mp4 "$file" ;;
            mkv|MKV) repair_mkv "$file" ;;
            *)       repair_general "$file" ;;
        esac
    done < <(find "$DIR" -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' \) -print0)

    log "INFO" "Verarbeitung abgeschlossen"
}

main "$@"
