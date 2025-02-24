#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Video Repair Tools ===${NC}"

# Option 1: HandBrakeCLI
if command -v HandBrakeCLI &> /dev/null; then
    echo -e "${GREEN}HandBrakeCLI is available${NC}"
    echo -e "${CYAN}Example repair command:${NC}"
    echo -e "HandBrakeCLI -i \"input.mp4\" -o \"repaired.mp4\" --preset=\"Fast 1080p30\""
else
    echo -e "${YELLOW}HandBrakeCLI not found${NC} (can be installed with: apt-get install handbrake-cli)"
fi

# Option 2: Mencoder (part of MPlayer)
if command -v mencoder &> /dev/null; then
    echo -e "${GREEN}mencoder is available${NC}"
    echo -e "${CYAN}Example repair command:${NC}"
    echo -e "mencoder \"input.mp4\" -ovc copy -oac copy -o \"repaired.mp4\""
else
    echo -e "${YELLOW}mencoder not found${NC} (can be installed with: apt-get install mencoder)"
fi

# Option 3: GStreamer
if command -v gst-launch-1.0 &> /dev/null; then
    echo -e "${GREEN}GStreamer is available${NC}"
    echo -e "${CYAN}Example repair command:${NC}"
    echo -e "gst-launch-1.0 filesrc location=\"input.mp4\" ! decodebin ! queue ! encodebin ! filesink location=\"repaired.mp4\""
else
    echo -e "${YELLOW}GStreamer not found${NC} (can be installed with: apt-get install gstreamer1.0-tools)"
fi

# Option 4: MLT Framework
if command -v melt &> /dev/null; then
    echo -e "${GREEN}MLT's melt is available${NC}"
    echo -e "${CYAN}Example repair command:${NC}"
    echo -e "melt \"input.mp4\" -consumer avformat:\"repaired.mp4\" acodec=copy vcodec=copy"
else
    echo -e "${YELLOW}MLT's melt not found${NC} (can be installed with: apt-get install melt)"
fi

# Option 5: avidemux_cli
if command -v avidemux_cli &> /dev/null; then
    echo -e "${GREEN}avidemux_cli is available${NC}"
    echo -e "${CYAN}Example repair command:${NC}"
    echo -e "avidemux_cli --load \"input.mp4\" --save \"repaired.mp4\" --output-format MP4 --video-codec copy --audio-codec copy"
else
    echo -e "${YELLOW}avidemux_cli not found${NC} (can be installed with: apt-get install avidemux-cli)"
fi
