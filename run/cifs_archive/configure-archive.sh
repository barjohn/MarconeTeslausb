#!/bin/bash -eu

function configure_archive () {
  echo "Configuring the archive..."
  
  local archive_path="/mnt/archive"

  if [ ! -e "$archive_path" ]
  then
    mkdir "$archive_path"  
  fi

  local cifs_version="${cifs_version:-3.0}"

  local credentials_file_path="/root/.teslaCamArchiveCredentials"
  /root/bin/write-archive-configs-to.sh "$credentials_file_path"

  echo "//$archiveserver/$sharename $archive_path cifs vers=${cifs_version},credentials=${credentials_file_path},iocharset=utf8,file_mode=0777,dir_mode=0777 0" >> /etc/fstab

  echo "Configured the archive."
}

configure_archive
