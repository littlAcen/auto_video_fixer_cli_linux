#!/bin/bash

# Directory where the videos are located
DIR="./videos"

# Check if VLC is installed
if ! command -v vlc &> /dev/null; then
    echo "VLC Media Player is required but not installed. Please install it and try again."
    exit 1
fi

# Loop through all video files in the directory
for file in "$DIR"/*; do
    # Check if the file is a video (you might want to limit to specific extensions)
    if [[ "$file" =~ \.(mp4|avi|mov|mkv|flv|wmv|mpeg|3gp)$ ]]; then
        echo "Processing $file..."
        
        # Attempt to play/repair with VLC; this is more symbolic since VLC GUI typically handles repairs
        vlc --play-and-exit "$file"
        
        # If you were using a typical command-line repair tool, you'd have:
        # repair-tool --repair "$file" --output "./repaired/${file##*/}"
        
        # Check if the file was "repaired" - you can make this check more meaningful
        if [ $? -eq 0 ]; then
            echo "Successfully processed $file."
        else
            echo "Failed to process $file."
        fi
    else
        echo "Skipping $file: Not a supported video format."
    fi
done

