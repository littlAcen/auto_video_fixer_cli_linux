repair_video() {
    input="$1"
    temp_output="${input}.repair_temp.mp4"
    
    echo -e "${BLUE}Attempting repair with ffmpeg...${NC}"
    if ffmpeg -err_detect ignore_err -i "$input" -c copy -y "$temp_output" 2>/dev/null; then
        if [ -s "$temp_output" ]; then
            mv "$temp_output" "$input"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}ffmpeg repair failed, trying mencoder...${NC}"
    if command -v mencoder &>/dev/null; then
        rm -f "$temp_output"
        if mencoder "$input" -ovc copy -oac copy -o "$temp_output" 2>/dev/null; then
            if [ -s "$temp_output" ]; then
                mv "$temp_output" "$input"
                return 0
            fi
        fi
    fi
    
    echo -e "${YELLOW}mencoder repair failed, trying HandBrakeCLI...${NC}"
    if command -v HandBrakeCLI &>/dev/null; then
        rm -f "$temp_output"
        if HandBrakeCLI -i "$input" -o "$temp_output" --preset="Fast 1080p30" 2>/dev/null; then
            if [ -s "$temp_output" ]; then
                mv "$temp_output" "$input"
                return 0
            fi
        fi
    fi
    
    rm -f "$temp_output"
    return 1
}
