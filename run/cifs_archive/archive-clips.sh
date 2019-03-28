#!/bin/bash -eu

log "Moving clips to archive..."

NUM_FILES_MOVED=0

function moveclips() {
  ROOT="$1"
  PATTERN="$2"

  while read file_name
  do
    if [ -d "$ROOT/$file_name" ]
    then
      log "Creating output directory '$file_name'"
      mkdir -p "$ARCHIVE_MOUNT/$file_name"
    elif [ -f "$ROOT/$file_name" ]
    then
      log "Moving '$file_name'"
      outdir=$(dirname "$file_name")
      if mv -f "$ROOT/$file_name" "$ARCHIVE_MOUNT/$outdir"
      then
        log "Moved '$file_name'"
      else
        log "Failed to move '$file_name'"
      fi
      NUM_FILES_MOVED=$((NUM_FILES_MOVED + 1))
    else
      log "$file_name not found"
    fi
  done <<< $(cd "$ROOT"; find $PATTERN)
}

# legacy file name pattern, firmware 2018.*
moveclips "$CAM_MOUNT/TeslaCam" 'saved*'

# new file name pattern, firmware 2019.*
moveclips "$CAM_MOUNT/TeslaCam/SavedClips" '*'

log "Moved $NUM_FILES_MOVED file(s)."

if [ $NUM_FILES_MOVED -gt 0 ]
then
  /root/bin/send-pushover "$NUM_FILES_MOVED"
fi

log "Finished moving clips to archive."
