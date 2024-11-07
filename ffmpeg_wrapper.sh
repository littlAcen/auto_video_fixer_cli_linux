#!/usr/bin/env bash

ffprocess () {
    file="$1"
    output="$2" 
    TIMECODE=$(ffprobe "$file" -v error -show_entries stream_tags=timecode -of default=noprint_wrappers=1:nokey=1 | awk -F: '{ print $1 "\\:" $2 "\\:" $3 "\\:" $4 }')
    ffmpeg -i "$file" \
    -vf "trim=start_frame=192,setpts=PTS-STARTPTS,scale=1280:-1:force_original_aspect_ratio=decrease,drawtext=fontfile=/usr/share/fonts/truetype/droid/DroidSansMono.ttf: fontsize=28: timecode='00\:00\:00\:00': r=24: x=(w-tw)/2: y=25: fontcolor=white: box=1: boxcolor=0x00000099" \
    -threads 4 \
    -c:v mpeg1video \
    -b:v 5000k \
    -af "atrim=start=8,asetpts=PTS-STARTPTS" \
    -c:a libmp3lame -b:a 192k \
    "${output}"
}

#This function gets called when a process is no longer valid and needs removing from the array

removeps () {
    trtmp=()
    for tmpps in "${ffpsid[@]}"
    do
        [[ $tmpps != "$1" ]] && trtmp+=($tmpps)
    done
    ffpsid=("${trtmp[@]}")
    unset trtmp
    return
}

#Checks to see if each process is still active
checkffpsid () {
    for ffps in "${ffpsid[@]}" 
    do 
    ps -p $ffps > /dev/null || removeps "$ffps"
done

}


if [[ "$#" -lt 2 ]]; then echo -e "Usage: $0 [ext] [maxproc]\ni.e. $0 .mov 5" ; exit ; fi

ext="$1"
maxproc="$2"
find . -maxdepth 1 -iname "*.$ext" > inputlist.txt   # Find files with ext specified
IFS=$'\n' read -rd '' -a filelist <<<"$(cat inputlist.txt)" 
for file in "${filelist[@]}"
    do
    name=$(basename "$file")
    name="${name%.*}"                                  # remove ext for name var
    outname="${name}_mpeg1.mpeg"                       # Set output name
    checkffpsid 
    if [ -f "$outname" ]
        then 
        echo "$outname" already exists, skipping ...
    else
        until [[ "${#ffpsid[@]}" -le "$maxproc" ]]
        do
            checkffpsid
            sleep 5
        done
        ffprocess "$file" "$outname" & ffpsid+=("$!") 
    fi
done
