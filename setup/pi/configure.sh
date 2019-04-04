#!/bin/bash -eu

REPO=${REPO:-marcone}
BRANCH=${BRANCH:-main-dev}

ARCHIVE_SYSTEM=${ARCHIVE_SYSTEM:-none}

export INSTALL_DIR=${INSTALL_DIR:-/root/bin}


function log_progress () {
  if typeset -f setup_progress > /dev/null; then
    setup_progress "$1"
  else
    echo "$1"
  fi
}

log_progress "$0 starting with REPO=$REPO, BRANCH=$BRANCH, ARCHIVE_SYSTEM=$ARCHIVE_SYSTEM, INSTALL_DIR=$INSTALL_DIR"

function check_variable () {
    local var_name="$1"
    if [ -z "${!var_name+x}" ]
    then
        log_progress "STOP: Define the variable $var_name like this: export $var_name=value"
        exit 1
    fi
}

function get_script () {
    local local_path="$1"
    local name="$2"
    local remote_path="${3:-}"

    log_progress "Starting download for $local_path/$name"
    curl -o "$local_path/$name" https://raw.githubusercontent.com/"$REPO"/teslausb/"$BRANCH"/"$remote_path"/"$name"
    chmod +x "$local_path/$name"
    log_progress "Done"
}

function install_rc_local () {
    local install_home="$1"

    if grep -q archiveloop /etc/rc.local
    then
        log_progress "Skipping rc.local installation"
        return
    fi

    log_progress "Configuring /etc/rc.local to run the archive scripts at startup..."
    echo "#!/bin/bash -eu" > ~/rc.local
    echo "archiveserver=\"${archiveserver}\"" >> ~/rc.local
    echo "install_home=\"${install_home}\"" >> ~/rc.local
    cat << 'EOF' >> ~/rc.local
LOGFILE=/tmp/rc.local.log

function log () {
  echo "$( date )" >> "$LOGFILE"
  echo "$1" >> "$LOGFILE"
}

log "Launching archival script..."
"$install_home"/archiveloop "$archiveserver" &
log "All done"
exit 0
EOF

    cat ~/rc.local > /etc/rc.local
    rm ~/rc.local
    log_progress "Installed rc.local."
}

function check_archive_configs () {
    log_progress "Checking archive configs: "

    case "$ARCHIVE_SYSTEM" in
        rsync)
            check_variable "RSYNC_USER"
            check_variable "RSYNC_SERVER"
            check_variable "RSYNC_PATH"
            export archiveserver="$RSYNC_SERVER"
            ;;
        rclone)
            check_variable "RCLONE_DRIVE"
            check_variable "RCLONE_PATH"
            export archiveserver="8.8.8.8" # since it's a cloud hosted drive we'll just set this to google dns    
            ;;
        cifs)
            check_variable "sharename"
            check_variable "shareuser"
            check_variable "sharepassword"
            check_variable "archiveserver"
            ;;
        none)
            ;;
        *)
            log_progress "STOP: Unrecognized archive system: $ARCHIVE_SYSTEM"
            exit 1
            ;;
    esac
    
    log_progress "done"
}

function get_archive_module () {

    case "$ARCHIVE_SYSTEM" in
        rsync)
            echo "run/rsync_archive"
            ;;
        rclone)
            echo "run/rclone_archive"
            ;;
        cifs)
            echo "run/cifs_archive"
            ;;
        *)
            echo "Internal error: Attempting to configure unrecognized archive system: $ARCHIVE_SYSTEM"
            exit 1
            ;;
    esac
}

function install_archive_scripts () {
    local install_path="$1"
    local archive_module="$2"

    log_progress "Installing base archive scripts into $install_path"
    get_script $install_path archiveloop run
    get_script $install_path remountfs_rw run

    log_progress "Installing archive module scripts"
    get_script $install_path verify-archive-configuration.sh $archive_module
    get_script $install_path configure-archive.sh $archive_module
    get_script $install_path archive-clips.sh $archive_module
    get_script $install_path connect-archive.sh $archive_module
    get_script $install_path disconnect-archive.sh $archive_module
    get_script $install_path write-archive-configs-to.sh $archive_module
    get_script $install_path archive-is-reachable.sh $archive_module
    if [ ! -z ${musicsharename:+x} ]
    then
      get_script $install_path copy-music.sh $archive_module
    fi
}

function check_pushover_configuration () {
    if [ ! -z "${pushover_enabled+x}" ]
    then
        if [ ! -n "${pushover_user_key+x}" ] || [ ! -n "${pushover_app_key+x}"  ]
        then
            log_progress "STOP: You're trying to setup Pushover but didn't provide your User and/or App key."
            log_progress "Define the variables like this:"
            log_progress "export pushover_user_key=put_your_userkey_here"
            log_progress "export pushover_app_key=put_your_appkey_here"
            exit 1
        elif [ "${pushover_user_key}" = "put_your_userkey_here" ] || [  "${pushover_app_key}" = "put_your_appkey_here" ]
        then
            log_progress "STOP: You're trying to setup Pushover, but didn't replace the default User and App key values."
            exit 1
        fi
    fi
}

function configure_pushover () {
    if [ ! -z "${pushover_enabled+x}" ]
    then
        log_progress "Enabling pushover"
        echo "export pushover_enabled=true" > /root/.teslaCamPushoverCredentials
        echo "export pushover_user_key=$pushover_user_key" >> /root/.teslaCamPushoverCredentials
        echo "export pushover_app_key=$pushover_app_key" >> /root/.teslaCamPushoverCredentials
    else
        log_progress "Pushover not configured."
    fi
}

function check_and_configure_pushover () {
    check_pushover_configuration
    
    configure_pushover
}

function install_pushover_scripts() {
    local install_path="$1"
    get_script $install_path send-pushover run
}

if [ "$ARCHIVE_SYSTEM" = "none" ]
then
    log_progress "Skipping archive configuration."
    exit 0
fi

if ! [ $(id -u) = 0 ]
then
    log_progress "STOP: Run sudo -i."
    exit 1
fi

if [ ! -e "$INSTALL_DIR" ]
then
    mkdir "$INSTALL_DIR"
fi

log_progress "Getting files from $REPO:$BRANCH"

check_and_configure_pushover
install_pushover_scripts "$INSTALL_DIR"

check_archive_configs

archive_module="$( get_archive_module )"
log_progress "Using archive module: $archive_module"

install_archive_scripts $INSTALL_DIR $archive_module
"$INSTALL_DIR"/verify-archive-configuration.sh
"$INSTALL_DIR"/configure-archive.sh

install_rc_local "$INSTALL_DIR"



