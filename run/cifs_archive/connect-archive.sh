#!/bin/bash -eu

function ensure_archive_is_mounted () {
  log "Ensuring cam archive is mounted..."
  ensure_mountpoint_is_mounted_with_retry "$ARCHIVE_MOUNT"
  log "Ensured cam archive is mounted."
  if [ -e "$MUSIC_ARCHIVE_MOUNT" ]
  then
    log "Ensuring music archive is mounted..."
    ensure_mountpoint_is_mounted_with_retry "$MUSIC_ARCHIVE_MOUNT"
    log "Ensured music archive is mounted."
  fi
}

ensure_archive_is_mounted
