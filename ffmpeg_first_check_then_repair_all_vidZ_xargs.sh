#!/bin/bash

# Use xargs with a specified number of concurrent processes
find . -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.m4v" -o -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.3gp" -o -iname "*.webm" \) -print0 | xargs -0 -I {} -P 4 bash -c '
  file="{}"
  echo "Checking file: \"$file\""
  
  # Verify if the video file is potentially corrupt
  ffmpeg -v error -i "$file" -f null - 2>error.log
  
  if [ -s error.log ]; then
    echo "Found errors in \"$file\", attempting repair..."
    repairedfile="${file%.*}_repaired.${file##*.}"
  
    # Attempt to repair the file
    ffmpeg -err_detect ignore_err -i "$file" -c:v copy -c:a copy -y "$repairedfile"
  
    if [ $? -eq 0 ]; then
      mv "$repairedfile" "$file" # Replace the original file with the repaired file
      echo "Successfully repaired and replaced: \"$file\""
    else
      echo "Failed to repair file: \"$file\""
      rm -f -- "$repairedfile"
    fi
  else
    echo "No errors detected in \"$file\""
  fi
  
  # Clean up the error log
  rm -f -- error.log
'

