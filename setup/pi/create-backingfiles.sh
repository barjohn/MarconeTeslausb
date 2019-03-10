#!/bin/bash -eu

CAM_SIZE="$1"
MUSIC_SIZE="$2"
BACKINGFILES_MOUNTPOINT="$3"

G_MASS_STORAGE_CONF_FILE_NAME=/etc/modprobe.d/g_mass_storage.conf

function first_partition_offset () {
  local filename="$1"
  local size_in_bytes=$(sfdisk -l -o Size -q --bytes "$1" | tail -1)
  local size_in_sectors=$(sfdisk -l -o Sectors -q "$1" | tail -1)
  local sector_size=$(($size_in_bytes/$size_in_sectors))
  local partition_start_sector=$(sfdisk -l -o Start -q "$1" | tail -1)
  echo $(($partition_start_sector*$sector_size))
}

# Note that this uses powers-of-two rather than the powers-of-ten that are
# generally used to marked storage.
function dehumanize () {
  echo $(($(echo $1 | sed 's/G/*1024M/;s/M/*1024K/;s/K/*1024/')))
}

function is_percent() {
  echo "$1" | grep '%' > /dev/null
}

function calc_size () {
  local requestedsize="$1"
  local availablesize="$(df --output=avail --block-size=1K $BACKINGFILES_MOUNTPOINT/ | tail -n 1)"
  if is_percent "$requestedsize"
  then
    local percent=$(echo $requestedsize | sed 's/%//')
    requestedsize="$(( $availablesize * $percent / 100 ))"
  else
    requestedsize="$(( $(dehumanize $requestedsize) / 1024 ))"
  fi
  if [ "$requestedsize" -gt "$availablesize" ]
  then
    requestedsize="$availablesize"
  fi
  echo $requestedsize
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

CAM_DISK_FILE_NAME="$BACKINGFILES_MOUNTPOINT/cam_disk.bin"
MUSIC_DISK_FILE_NAME="$BACKINGFILES_MOUNTPOINT/music_disk.bin"

# delete existing files, because fallocate doesn't shrink files, and
# because they interfere with the percentage-of-free-space calculation
rm -f "$CAM_DISK_FILE_NAME"
rm -f "$MUSIC_DISK_FILE_NAME"

CAM_DISK_SIZE="$(calc_size $CAM_SIZE)"
MUSIC_DISK_SIZE="$(calc_size $MUSIC_SIZE)"

add_drive "cam" "CAM" "$CAM_DISK_SIZE" "$CAM_DISK_FILE_NAME"

REMAINING_SPACE="$(df --output=avail --block-size=1K $BACKINGFILES_MOUNTPOINT/ | tail -n 1)"
if [ "$REMAINING_SPACE" -gt 0 -a "$MUSIC_SIZE" != "" ]
then
  add_drive "music" "MUSIC" "$MUSIC_DISK_SIZE" "$MUSIC_DISK_FILE_NAME"
  echo "options g_mass_storage file=$MUSIC_DISK_FILE_NAME,$CAM_DISK_FILE_NAME removable=1,1 ro=0,0 stall=0 iSerialNumber=123456" > "$G_MASS_STORAGE_CONF_FILE_NAME"
else
  echo "options g_mass_storage file=$CAM_DISK_FILE_NAME removable=1 ro=0 stall=0 iSerialNumber=123456" > "$G_MASS_STORAGE_CONF_FILE_NAME"
fi

create_teslacam_directory
