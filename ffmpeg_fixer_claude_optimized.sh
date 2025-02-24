#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Create a single error log file with timestamp in the current directory
error_log="video_repair_$(date +%Y%m%d_%H%M%S).log"
corrected_log="$error_log.corrected"

echo -e "${BOLD}=== Video Repair Process Started at $(date) ===${NC}" | tee "$error_log"
echo "Files that required repair:" > "$corrected_log"

# Count total files first to show progress
echo -e "${BLUE}Finding all video files...${NC}"
video_files=()
while IFS= read -r -d $'\0' file; do
  video_files+=("$file")
done < <(find "$(pwd)" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" \
  -o -name "*.flv" -o -name "*.wmv" -o -name "*.m4v" -o -name "*.mpg" -o -name "*.mpeg" \
  -o -name "*.3gp" -o -name "*.webm" \) -print0)

total_files=${#video_files[@]}
echo -e "${BLUE}Found $total_files video files to check${NC}" | tee -a "$error_log"

# Process all files
repaired_files=0
failed_repairs=0
current=0

for file in "${video_files[@]}"; do
  ((current++))
  echo -e "\n${CYAN}[$current/$total_files] Checking file: \"$file\"${NC}" | tee -a "$error_log"
  
  # Check for errors
  echo -e "${BLUE}Running error check...${NC}" | tee -a "$error_log"
  temp_err="temp_err_$RANDOM.log"
  ffmpeg -v error -i "$file" -t 10 -f null - 2>"$temp_err"
  
  if [ -s "$temp_err" ]; then
    echo -e "  ${RED}[ERROR]${NC} Found errors in \"$file\"" | tee -a "$error_log"
    echo -e "  ${YELLOW}Error details:${NC}" | tee -a "$error_log"
    cat "$temp_err" | tee -a "$error_log"
    
    repairedfile="${file}.temp_repair"
    repair_log="repair_log_$RANDOM.txt"
    
    echo -e "  ${BLUE}Attempting repair...${NC}" | tee -a "$error_log"
    ffmpeg -err_detect ignore_err -i "$file" -c copy -y "$repairedfile" 2>"$repair_log"
    
    if [ -f "$repairedfile" ] && [ -s "$repairedfile" ]; then
      echo -e "  ${BLUE}Replacing original with repaired file...${NC}" | tee -a "$error_log"
      mv "$repairedfile" "$file"
      echo -e "  ${GREEN}[SUCCESS]${NC} Repaired and replaced: \"$file\"" | tee -a "$error_log"
      echo "\"$file\"" >> "$corrected_log"
      ((repaired_files++))
    else
      echo -e "  ${RED}[FAILED]${NC} Could not repair: \"$file\"" | tee -a "$error_log"
      echo -e "  ${YELLOW}Repair attempt details:${NC}" | tee -a "$error_log"
      cat "$repair_log" | tee -a "$error_log"
      rm -f "$repairedfile"
      ((failed_repairs++))
    fi
    
    echo -e "${MAGENTA}----------------------------------------${NC}" | tee -a "$error_log"
    rm -f "$repair_log"
  else
    echo -e "  ${GREEN}[OK]${NC} No errors detected" | tee -a "$error_log"
  fi
  
  rm -f "$temp_err"
done

# Print summary
echo -e "\n${BOLD}=== Video Repair Process Completed at $(date) ===${NC}" | tee -a "$error_log"
echo -e "${BOLD}${BLUE}Total files checked: $total_files${NC}" | tee -a "$error_log"
echo -e "${BOLD}${GREEN}Total files repaired: $repaired_files${NC}" | tee -a "$error_log"
echo -e "${BOLD}${RED}Failed repairs: $failed_repairs${NC}" | tee -a "$error_log"
echo "Total files repaired: $repaired_files" >> "$corrected_log"

echo -e "${BOLD}Process complete.${NC}"
echo -e "${BLUE}Full log available in: $error_log${NC}"
echo -e "${BLUE}List of corrected files available in: $corrected_log${NC}"
