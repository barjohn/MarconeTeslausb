#!/bin/bash -eu

log "Copying music from  archive..."

NUM_FILES_COPIED=0
SRC="/mnt/musicarchive"
DST="/mnt/music"

while read file_name
do
  if [ ! -e "$DST/$file_name" ]
  then
    dir=$(dirname "$file_name")
    mkdir -p "$DST/$dir"
    cp "$SRC/$file_name" "$DST/$dir/tmp"
    mv "$DST/$dir/tmp" "$DST/$file_name"
    NUM_FILES_COPIED=$((NUM_FILES_COPIED + 1))
  fi
done <<< "$(cd "$SRC"; find * -type f)"

log "Copied $NUM_FILES_COPIED music file(s)."
