find . -type f -iname "*.mp4" | while IFS= read -r file; do
  tmpfile="${file%.*}_temp.mp4"
  repairedfile="${file%.*}_repaired.mp4"

  # Fragmentiere die Datei, um Container-Probleme zu beheben
  mp4fragment "$file" "$tmpfile"
  if [ $? -eq 0 ]; then
    echo "Fragmentation successful for $file."

    # Repariere die Datei mit ffmpeg
    ffmpeg -err_detect ignore_err -i "$tmpfile" -c:v copy -c:a copy -y "$repairedfile"
    if [ $? -eq 0 ]; then
      echo "Repair successful with ffmpeg: $file"
      rm "$tmpfile"
      mv "$repairedfile" "$file"
    else
      echo "Failed to repair file with ffmpeg: $file"
      rm "$repairedfile"
      rm "$tmpfile"
    fi
  else
    echo "Failed to fragment file with mp4fragment: $file"
    rm -f "$tmpfile"
  fi
done

