#!/bin/bash

for file in *.mp4
do
ffmpeg -i "$file" -c:v libx264  -crf 23 "${file%.*}_crf".mp4
done

