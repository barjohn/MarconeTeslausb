#!/bin/bash -eu

CAM_PERCENT="$1"
BACKINGFILES_MOUNTPOINT="$2"

G_MASS_STORAGE_CONF_FILE_NAME=/etc/modprobe.d/g_mass_storage.conf

function first_partition_offset () {
  local filename="$1"
  local size_in_bytes=$(sfdisk -l -o Size -q --bytes "$1" | tail -1)
  local size_in_sectors=$(sfdisk -l -o Sectors -q "$1" | tail -1)
  local sector_size=$(($size_in_bytes/$size_in_sectors))
  local partition_start_sector=$(sfdisk -l -o Start -q "$1" | tail -1)
  echo $(($partition_start_sector*$sector_size))
}

function add_drive () {
  local name="$1"
  local label="$2"
  local size="$3"

  local filename="$4"
  echo "Allocating ${size}K for $filename..."
  fallocate -l "$size"K "$filename"
  echo "type=c" | sfdisk "$filename" > /dev/null
  local partition_offset=$(first_partition_offset "$filename")
  losetup -o $partition_offset loop0 "$filename"
  mkfs.vfat /dev/loop0 -F 32 -n "$label"
  losetup -d /dev/loop0

  local mountpoint=/mnt/"$name"

  if [ ! -e "$mountpoint" ]
  then
    mkdir "$mountpoint"
    echo "$filename $mountpoint vfat noauto,users,umask=000,offset=$partition_offset 0 0" >> /etc/fstab
  fi
}

function create_teslacam_directory () {
  mount /mnt/cam
  mkdir /mnt/cam/TeslaCam
  umount /mnt/cam
}

FREE_1K_BLOCKS="$(df --output=avail --block-size=1K $BACKINGFILES_MOUNTPOINT/ | tail -n 1)"

CAM_DISK_SIZE="$(( $FREE_1K_BLOCKS * $CAM_PERCENT / 100 ))"
CAM_DISK_FILE_NAME="$BACKINGFILES_MOUNTPOINT/cam_disk.bin"
add_drive "cam" "CAM" "$CAM_DISK_SIZE" "$CAM_DISK_FILE_NAME"

if [ "$CAM_PERCENT" -lt 100 ]
then
  MUSIC_DISK_SIZE="$(df --output=avail --block-size=1K $BACKINGFILES_MOUNTPOINT/ | tail -n 1)"
  MUSIC_DISK_FILE_NAME="$BACKINGFILES_MOUNTPOINT/music_disk.bin"
  add_drive "music" "MUSIC" "$MUSIC_DISK_SIZE" "$MUSIC_DISK_FILE_NAME"
  echo "options g_mass_storage file=$MUSIC_DISK_FILE_NAME,$CAM_DISK_FILE_NAME removable=1,1 ro=0,0 stall=0 iSerialNumber=123456" > "$G_MASS_STORAGE_CONF_FILE_NAME"
else
  echo "options g_mass_storage file=$CAM_DISK_FILE_NAME removable=1 ro=0 stall=0 iSerialNumber=123456" > "$G_MASS_STORAGE_CONF_FILE_NAME"
fi

create_teslacam_directory
