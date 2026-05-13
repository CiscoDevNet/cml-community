#!/bin/bash
#
# This file is part of VIRL 2
# Copyright (c) 2019-2026, Cisco Systems, Inc.
# All rights reserved.
#

# the sysadmin username in the source server for online migration
DEFAULT_USER="sysadmin"

ME=$(basename "$0")
LOCAL_ME=$0
OTHER_ME=/tmp/$ME
DEF_FILE=/etc/default/virl2
source "$DEF_FILE"
: "${IS_CONNECTOR:=1}"
set -euo pipefail

# Version of this script in semver 2.0 format.
_VERSION="2.4.3"

# Supported versions of source and target hosts for upgrade
# The max versions are above last supported version
SOURCE_MIN=2.6.0
SOURCE_MAX=2.11.0
TARGET_MIN=2.8.0
TARGET_MAX=2.11.0

# Flag whether source and target have potential LXC nodes
SOURCE_LXC=false
TARGET_LXC=false

# The branch from which to grab the canonical, stable latest version of the script.
GITHUB_BRANCH="master"

# This is the link to the raw GitHub source for the script itself.
GITHUB_URL="https://raw.githubusercontent.com/CiscoDevNet/cml-community/$GITHUB_BRANCH/scripts/migration-tool/virl2-migrate-data.sh"

# Services which need stopping and restarting
CML_SERVICES=(virl2.target)
# Source directories; the array items are sometimes used unquoted
IMG_DIR="$BASE_DIR/images"
SRC_DIRS=("$IMG_DIR")
if [[ "$IS_CONNECTOR" == 1 ]]; then
    # only controllers hold DB, image and node definitions
    SRC_DIRS+=("$CFG_DIR" "$LIBVIRT_IMAGES")
fi

KEY_FILE="migration_key"
CFG_FILE="migration_cfg"
SSH_PORT="1122"
# marker for check_disk_size to calculate required size from list of paths
DU="_calculate_"
# Migration here means upgrade from a supported release to a current one
DOING_MIGRATION=false
HOSTNAME=$(hostname --short)
IOL_RUNNER="iol-runner-*.tar.gz"
# Files that should not be packed up: failed metadata patches, sockets, IOL base image
EXCLUDES=("--exclude="{"*."{rej,orig,sock},"netio*/[t0-9]*","$IOL_RUNNER"})
# Contains all persistent domains and networks under subdirectories that need not exist
LIBVIRT_XML="/etc/libvirt"

# Compute a timestamp, avoiding colons so that it's easier to use in filenames.
TIMESTAMP=$(printf '%(%Y-%m-%d_%H-%M-%S_%Z)T')

# Progress indicator config for tar
tar_checkpoint_action=' printf "\e[1;34m%s of %s copied  %d/100%% complete  \e[0m\r" '
tar_checkpoint_action+='$(numfmt --to=iec-i $((10000*$TAR_CHECKPOINT)) ) '
tar_checkpoint_action+='$(numfmt --to=iec-i $((10000*$total)) )\t'
tar_checkpoint_action+='$((100*$TAR_CHECKPOINT/$total)) '

check_for_updates() {
    local rc=0
    curl -s --output "$OTHER_ME" "$GITHUB_URL" || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to download GitHub source.  Not updating."
        return $rc
    fi

    gh_version=$(sed -n -e '/^_VERSION=/{s/.*="\([^"]*\)"/\1/p;q}' "$OTHER_ME")
    if [[ -z "$gh_version" ]]; then
        echo "Unable to find version from GitHub source.  Not updating."
        return 1
    fi

    if dpkg --compare-versions "$gh_version" le "$_VERSION"; then
        echo "GitHub source version is not newer than the current version.  Not updating."
        return 0
    fi

    cp -b -S ".$_VERSION" "$OTHER_ME" "$LOCAL_ME"
    chmod +x "$LOCAL_ME"

    echo "Successfully updated to $gh_version.  Please re-run $LOCAL_ME."

    return 0
}

grepok() {
    # Exit 0 even if 0 lines are output
    grep "$@" || true
}

ask_confirm() {
    if ! $NO_CONFIRM; then
        read -r -p "$1 [y/N] " confirm
        echo
        if [[ "$confirm" != y* ]]; then
            echo "Terminating $2."
            exit 0
        fi
    fi
}

cleanup_local() {
    set +e
    if [[ -n "$WORKING_DIR" && -d "$WORKING_DIR" ]]; then
        rm -rf "$WORKING_DIR"
    fi
}

cleanup_backup() {
    set +e
    echo
    echo "Cleaning up..."
    echo

    restart_cml_services
    cleanup_local

    if [[ -z "${rc:-}" ]]; then
        rc=1
    fi

    if [[ $rc != 0 ]]; then
        rm -f "$BACKUP_FILE"
    fi

    exit $rc
}

cleanup_failed_restore() {
    set +e
    echo
    echo "Cleaning up..."
    echo

    restart_cml_services
    cleanup_local

    if [[ -z "${rc:-}" ]]; then
        rc=1
    fi

    exit $rc
}

cleanup_remote_from_host() {
    set +e
    # Path chosen by --prepare-export on the source host.
    local remote_dir=${REMOTE_WORK_DIR:-}
    ssh "${ssh_opts[@]}" "$host" \
        "sudo $OTHER_ME --start; \
        sudo rm -rf ${remote_dir:+\"$remote_dir\"} $OTHER_ME /etc/sudoers.d/cml-migrate; \
        (cp -fa ~/.ssh/authorized_keys{.migration,} &>/dev/null || true)"
}

cleanup_failed_from_host() {
    set +e
    echo
    echo "Cleaning up on remote host..."
    echo

    cleanup_remote_from_host
    restart_cml_services
    cleanup_local

    if [[ -z "${rc:-}" ]]; then
        rc=1
    fi

    exit $rc
}

set_virl_version() {
    local product_file=${1:-/PRODUCT}
    local version
    version=$(jq -r ".PRODUCT_VERSION" <"$product_file" | sed -e 's/-.*//')

    if [[ $# == 1 ]]; then
        echo "$version"
    else
        VIRL_VERSION=$version
    fi
}

copy_xml() {
    find "$origin" -maxdepth 1 -name '*.xml' -print0 | xargs -0 -r cp -t "$target"
}

prepare_export() {
    {
        printf "# CML2 migration on %s.\n" "$(date)"
        printf "\n## hostname \n"
        hostname
        printf "\n## ip link show \n"
        ip link show
        printf "\n## nmcli \n"
        if nmcli; then
            printf "\n## nmcli con show \n"
            nmcli con show
            printf "\n## nmcli con show bridge0 \n"
            nmcli con show bridge0
        else
            echo "NetworkManager is not available"
        fi
    } >"$CFG_DIR"/migration_info.txt

    mkdir -p "$WORKING_DIR"/{kvm,net}
    local target="$WORKING_DIR/kvm" origin="$LIBVIRT_XML/qemu"
    if [ -d "$origin" ]; then
        copy_xml
    fi

    origin="$LIBVIRT_XML/lxc"
    if "$SOURCE_LXC" && [ -d "$origin" ]; then
        target="$WORKING_DIR/lxc"
        mkdir -p "$target"
        copy_xml
    fi

    origin="$LIBVIRT_XML/qemu/networks"
    if [ -d "$origin" ]; then
        target="$WORKING_DIR/net"
        copy_xml
    fi

    cp "$DEF_FILE" "$WORKING_DIR/$CFG_FILE"
}

perform_restore() {
    reconfigure_host
    import_libvirt_resources
    if $DOING_MIGRATION; then
        migrate_host
    fi
    if dpkg --compare-versions "$VIRL_VERSION" ge 2.9.1 && systemctl is-enabled virl2-core-driver &>/dev/null; then
        /usr/local/bin/virl2-core-driver.sh upgrade
    fi
    /usr/local/bin/virl2-lowlevel-driver.sh upgrade
}

migrate_host() {
    # DB migration only on the controller
    if [[ "$IS_CONNECTOR" != 1 ]]; then
        return 0
    fi
    echo "Performing DB migration..."
    local rc=0
    local output
    output=$( (
        chown -R www-data:www-data "$CFG_DIR"
        find "$BASE_DIR"/images -xdev -type f \( -name "*.img" -or -name "nodedisk*" \) -print0 |
            xargs -0 chown libvirt-qemu:kvm 2>/dev/null
        # env vars should match expected variables in postinst alembic upgrade
        cd "$BASE_DIR"/db_migrations &&
            env CFG_DIR="$CFG_DIR" BASE_DIR="$BASE_DIR" VIRL2_DIR="$BASE_DIR" HOME="$BASE_DIR" \
                COMPUTE_ID="$COMPUTE_ID" MIGRATION=1 HOSTNAME="$HOSTNAME" \
                "$BASE_DIR"/.local/bin/alembic upgrade head
    ) 2>&1) || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to execute data upgrade scripts:"
        printf '%s\n\n' "$output"
        return $rc
    else
        echo "Migration completed SUCCESSFULLY."
    fi
}

reconfigure_host() {
    local cfg_file="$WORKING_DIR"/"$CFG_FILE"
    local extract_id='/^COMPUTE_ID=/{s/.*=[^0-9a-fA-F]\?\([0-9a-fA-F-]\{36\}\).*/\1/p;q}'
    local helper="/usr/local/bin/virl2-issue-helper.sh"
    local compute_id
    compute_id=$(sed -n -e "$extract_id" "$cfg_file")
    if [[ -n "$compute_id" ]]; then
        sed -i -e 's/^\(COMPUTE_ID=\).*/\1"'"$compute_id"'"/' "$DEF_FILE"
        if [[ -x "$helper" ]]; then
            "$helper"
        fi
        echo "Host compute ID has been set to $compute_id"
    fi
}

import_libvirt_resources() {
    local rc=0
    local resource
    for resource in domain network; do
        local output
        output=$(define_${resource}s 2>&1) || rc=$?
        if [[ $rc != 0 ]]; then
            echo "Libvirt $resource import completed with errors:"
            printf '%s\n\n' "$output"
            return $rc
        fi
    done
    if [[ $rc == 0 ]]; then
        echo "Restore completed SUCCESSFULLY."
    fi
    return $rc
}

list_resources() {
    local resource=$1
    local resource_dir="$WORKING_DIR/$resource"
    if [[ -d "$resource_dir" ]]; then
        find "$resource_dir" -name '*.xml'
    fi
}

define_domains() {
    local rc=0
    local resource_xml
    while read -r resource_xml <&3; do
        virsh define "$resource_xml" || rc=$?
        if [[ $rc != 0 ]]; then
            return $rc
        fi
    done 3< <(list_resources kvm)

    if ! "$SOURCE_LXC"; then
        return 0
    fi

    if ! "$TARGET_LXC"; then
        # All LXC nodes are IOL, hence prepare them for conversion to Docker
        local node_id
        local -a node_dirs
        while read -r resource_xml <&3; do
            node_id="$(basename "$resource_xml" .xml)"
            node_dirs=("$BASE_DIR/images/"*"/$node_id/")
            if [[ -d "${node_dirs[0]}" ]]; then
                mv "$resource_xml" "${node_dirs[0]}/domain.xml"
            fi
        done 3< <(list_resources lxc)
        return 0
    fi
    while read -r resource_xml <&3; do
        virsh -c lxc:/// define "$resource_xml" || rc=$?
        if [[ $rc != 0 ]]; then
            return $rc
        fi
    done 3< <(list_resources lxc)
}

undefine_network_if_exists() {
    local network="$1"
    local rc=0
    local state
    state=$(virsh net-info "$network" 2>/dev/null) || rc=$?
    if [[ $rc != 0 ]]; then
        return 0
    fi
    if grep -q 'Active:.*yes' <<<"$state"; then
        virsh net-destroy "$network"
    fi
    virsh net-undefine "$network"
}

define_networks() {
    local resource_xml
    while read -r resource_xml <&3; do
        local network
        network=$(basename "$resource_xml" .xml)
        if [[ "$network" == default ]] && ! grep -q 'cml:cml' "$resource_xml"; then
            # Maybe we should skip all networks which are not marked by CML
            echo "Skipping import of default network as it is not adjusted for cml"
            continue
        fi
        undefine_network_if_exists "$network"
        virsh net-define "$resource_xml"
        if [[ "$network" != ums-* ]]; then
            virsh net-start "$network"
        fi
    done 3< <(list_resources net)
}

prepare_local() {
    local rc=0
    stop_cml_services || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to stop CML services."
        return $rc
    fi
    {
        delete_libvirt_domains
        delete_libvirt_networks
    } || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to remove pre-existing node and network resources."
        return $rc
    fi

    # Remove stale SQLite WAL/SHM so they are not replayed onto the
    # freshly synced controller.db ("database disk image is malformed").
    if [[ "$IS_CONNECTOR" == 1 ]]; then
        rm -f "$CFG_DIR"/controller.db-wal "$CFG_DIR"/controller.db-shm
    fi
    return $rc
}

delete_libvirt_domains() {
    virsh list --all --name | grepok -v '^ *$' | xargs -rn1 virsh undefine --nvram >/dev/null
    if "$TARGET_LXC"; then
        virsh -c lxc:/// list --all --name | grepok -v '^ *$' | xargs -rn1 virsh -c lxc:/// undefine >/dev/null
    fi
}

delete_libvirt_networks() {
    virsh net-list --all --name | grepok "^ums" | xargs -rn1 virsh net-undefine >/dev/null
}

check_disk_space() {
    local target=$1
    local total_needed=$2
    if [[ "$total_needed" == "$DU" ]]; then
        shift 2
        total_needed=$(du -B1 -sc "$@" | sed -n -E -e 's|\s+total||p')
    fi

    local total_available mount_point
    read -r total_available mount_point < <(df -B1 --output=avail,target "$target" | grep '^[0-9]')

    if [[ "$total_needed" -gt "$total_available" ]]; then
        echo "Insufficient disk space available in $mount_point for $target;"
        echo "$total_needed bytes required but only $total_available bytes available."
        return 1
    fi

    return 0
}

wait_for_vms_to_stop() {
    local -i loops=5 # max 5x5 = 25s
    local have_docker=false check_libvirt=true check_docker=true
    if type docker &>/dev/null; then
        have_docker=true
    fi
    if ! pgrep libvirtd &>/dev/null; then
        echo "Libvirt service is not running and node state cannot be determined."
        ask_confirm "Assume all VMs have been properly stopped?" "pre-check"
        check_libvirt=false
    fi
    if "$have_docker" && ! pgrep dockerd &>/dev/null; then
        echo "Docker service is not running and node state cannot be determined."
        ask_confirm "Assume all containers have been properly stopped?" "pre-check"
        check_docker=false
    fi
    while [[ $loops -gt 0 ]]; do
        local running
        running=$({
            if "$check_libvirt"; then
                virsh list --name
                virsh -c lxc:/// list --name
            fi
            if "$have_docker" && "$check_docker"; then
                docker ps --format '{{.Names}}'
            fi
        } | grepok -vc '^ *$')
        if [[ "$running" == 0 ]]; then
            return 0
        fi
        echo "Still running $running nodes"
        loops+=-1
        sleep 5
    done
    echo "Some labs are still running; please stop all labs before continuing"
    return 1
}

stop_cml_services() {
    local rc=0
    wait_for_vms_to_stop || rc=$?
    if [[ $rc != 0 ]]; then
        return $rc
    fi
    systemctl stop "${CML_SERVICES[@]}" || rc=$?
    if [[ $rc != 0 ]]; then
        return $rc
    fi

    echo "Waiting for controller to become inactive..."
    while [[ "$(systemctl is-active virl2-controller)" == "active" ]]; do
        echo "  Still active..."
        sleep 5
    done
    return $rc
}

restart_cml_services() {
    echo "Restarting CML services..."
    systemctl --no-block start "${CML_SERVICES[@]}"
}

# compatibility checks
# also adjusts DOING_MIGRATION, CML_SERVICES and SRC_DIRS, it needs to be called
# before those variables are used (e.g. prepare_local, check_disk_size)
check_cml_versions() {
    # import and restore
    local source_version=${1:-}
    local target_version=$VIRL_VERSION
    if [[ $# -eq 0 ]]; then
        # export, backup, stop, start
        source_version=$VIRL_VERSION
        if dpkg --compare-versions "$VIRL_VERSION" lt "$TARGET_MIN"; then
            target_version=$TARGET_MIN
        fi
    fi

    if dpkg --compare-versions "$target_version" lt $TARGET_MIN; then
        echo "This tool no longer supports CML version '$target_version'."
        echo "Please use the version matching your target host release"
        return 1
    elif dpkg --compare-versions "$target_version" ge $TARGET_MAX; then
        # We don't know how to migrate onto future releases
        echo "This tool does not support CML version '$target_version'."
        echo "Please use the version matching your target host release"
        return 1
    fi

    if [[ -z "$source_version" ]]; then
        return 0
    fi
    if dpkg --compare-versions "$source_version" lt $SOURCE_MIN; then
        echo "This tool can no longer migrate CML version '$source_version'."
        return 1
    fi
    if dpkg --compare-versions "$source_version" ge $SOURCE_MAX; then
        echo "This tool does not support migration from CML version" \
            "'$source_version' to '$target_version'."
        echo "Please use the version matching your target host release"
        return 1
    fi
    if dpkg --compare-versions "${source_version%%[+-]*}" gt "${target_version%%[+-]*}"; then
        echo "The source host CML version is newer than this host's." \
            "Cannot downgrade from '$source_version' to '$target_version'."
        return 1
    fi

    if dpkg --compare-versions "$source_version" lt "$target_version"; then
        DOING_MIGRATION=true
    fi
    if dpkg --compare-versions "$source_version" ge 2.9.0; then
        CML_SERVICES+=(docker{,.socket})
        SRC_DIRS+=(/var/lib/docker/{containers,image,overlay2})
    fi
    if dpkg --compare-versions "$source_version" lt 2.10.0; then
        SOURCE_LXC=true
    fi
    if dpkg --compare-versions "$target_version" lt 2.10.0; then
        TARGET_LXC=true
    fi

    return 0
}

check_cml_is_connector() {
    if [[ $IS_CONNECTOR == "$1" ]]; then
        return 0
    fi
    echo "Only one of this host and original host are a controller"
    echo "You must only migrate a controller to a controller, and each"
    echo "compute host to a different compute host."
    return 1
}

sync_from_host() {
    rc=0
    host=$1
    host_ip="$host"
    # used in scp/rsync commands to support ipv6
    scp_rsync_host="$host"
    if grep -qE '[a-zA-Z]' <<<"$host_ip"; then
        host_ip=$(host -t A "$host_ip" | grep -oE '[0-9][0-9.]+')
        if [[ $? != 0 ]]; then
            echo "Failed to lookup host $host.  Please specify a valid IP or hostname."
            return 1
        fi
    elif grep -qE '^([0-9a-fA-F:]{1,5}){3,8}$' <<<"$host_ip"; then
        scp_rsync_host="[$host]"
    fi
    if ip addr show | grep "inet6* $host_ip/" >/dev/null; then
        echo "You are trying to migrate from the local host.  Please specify another host from which to migrate."
        return 1
    fi

    if ! nc -z "$host" "$ssh_port"; then
        echo "Remote host does not have OpenSSH enabled; start the OpenSSH service from Cockpit on the source host."
        return 1
    fi

    ask_confirm "Do you wish to import data from $host? This will replace current local data" "import"

    ssh-keygen -b 4096 -q -N "" -f "$WORKING_DIR"/$KEY_FILE
    key=$(<"$WORKING_DIR/$KEY_FILE.pub")
    ssh_opts=(-o StrictHostKeyChecking=no -o Port="$ssh_port")
    ssh_opts+=(-o User="$sysadmin_user" -i "$WORKING_DIR/$KEY_FILE")

    printf "\nThe next prompt will be for %s's password on %s.\n" "$sysadmin_user" "$host"
    printf "The prompt following that will be for %s's password on %s to enter sudo mode.\n\n" "$sysadmin_user" "$host"
    # Stop the service on the remote host and make sure we don't need
    # a password for sudo.  We also install the SSH pubkey for subsequent logins.
    ssh -t "${ssh_opts[@]}" "$host" "echo '%$sysadmin_user        ALL=(ALL)       NOPASSWD: ALL' |\
        sudo tee /etc/sudoers.d/cml-migrate >/dev/null 2>&1 && mkdir -p ~/.ssh && \
        chmod 0700 ~/.ssh && \
        (cp -fa ~/.ssh/authorized_keys{,.migration} &>/dev/null || true) && \
        echo $key | tee -a ~/.ssh/authorized_keys &>/dev/null && \
        chmod 0600 ~/.ssh/authorized_keys" || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Error preparing $host for migration."
        return $rc
    fi

    # Install this script on the remote host.
    scp "${ssh_opts[@]}" "$LOCAL_ME" "$scp_rsync_host":"$OTHER_ME" >/dev/null || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Error copying $LOCAL_ME to source host."
        return $rc
    fi

    echo "Checking remote host.."
    # Check CML versions on both hosts.
    output=$(ssh "${ssh_opts[@]}" "$host" "sudo $OTHER_ME --cml-identify") || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to identify remote CML: $output"
        return $rc
    fi
    IFS='#' read -r is_connector virl_version hostname <<<"$output"
    if check_cml_versions "$virl_version" && check_cml_is_connector "$is_connector"; then
        echo "Preliminary checks pass."
        ask_confirm "Do you want to continue transfer from host '$hostname' into '$HOSTNAME'?" "transfer"
    else
        return 1
    fi

    # Stop CML services on remote host.
    ssh "${ssh_opts[@]}" "$host" "sudo chmod +x $OTHER_ME && sudo $OTHER_ME --stop" 2>/dev/null || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to stop source CML services."
        return $rc
    fi

    trap cleanup_failed_from_host SIGINT ERR

    # Capture the mktemp path the source host picked for the export.
    output=$(ssh "${ssh_opts[@]}" "$host" "sudo $OTHER_ME --prepare-export") || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to prepare export on $host"
        return $rc
    fi
    REMOTE_WORK_DIR=$(grep -oE 'PREPARE_EXPORT_PATH=\S+' <<<"$output" | tail -1 | cut -d= -f2)
    if [[ -z "$REMOTE_WORK_DIR" ]]; then
        echo "Source host did not return a working-dir path; aborting."
        return 1
    fi
    SRC_DIRS+=("$REMOTE_WORK_DIR")

    # Get required disk space from remote host
    output=$(ssh "${ssh_opts[@]}" "$host" "sudo du -B1 -sc ${SRC_DIRS[*]} | sed -n -E -e 's|\s+total||p'" 2>/dev/null) || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to determine migrated data size requirement on source host"
        return $rc
    fi

    echo "Preparing this host..."
    prepare_local || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to prepare before syncing"
        return $rc
    fi

    if ! check_disk_space "$BASE_DIR" "$output"; then
        return 1
    fi

    printf "Starting migration.  Please be patient, migration may take a while....\n\n\n"
    rsync_opts=("-aAvzXR" "--progress" "--checksum" "--rsync-path=sudo rsync" "-e" "ssh ${ssh_opts[*]}")
    rsync "${rsync_opts[@]}" "${EXCLUDES[@]}" "${SRC_DIRS[@]/#/$scp_rsync_host:}" / || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Migration completed with errors.  See the output above for details."
        return $rc
    fi
    printf "\nData transfer completed SUCCESSFULLY.\n"
    perform_restore

    trap - SIGINT ERR
    restart_cml_services
    printf "\nFinishing up with the remote host...\n"
    cleanup_remote_from_host
    printf "DONE.\n"
    return $rc
}

set_virl_version

if [[ "$EUID" != 0 ]]; then
    echo "This script must be run as root.  Use 'sudo' to run it."
    exit 1
fi

if ! opts=$(getopt -o brf:h:vu: --long host:,file:,backup,restore,cml-identify,stop,start,prepare-export,no-confirm,user:,port:,version,update -- "$@"); then
    echo "usage: $0 -h|--host HOST_TO_MIGRATE_FROM [-p|--port SSH_PORT=$SSH_PORT] [-u|--user USER=$DEFAULT_USER]"

    echo "       OR"
    echo "       $0 -b|--backup|-r|--restore -f|--file PATH_TO_BACKUP_FILE"
    exit 1
fi

REMOTE_HOST=
BACKUP_FILE=
BACKUP=false
RESTORE=false
NO_CONFIRM=false

sysadmin_user=$DEFAULT_USER
ssh_port=$SSH_PORT
WORKING_DIR=

eval set -- "$opts"
while true; do
    case "$1" in
        -h | --host)
            shift
            REMOTE_HOST=$1
            ;;
        -f | --file)
            shift
            BACKUP_FILE=$1
            ;;
        -b | --backup)
            BACKUP=true
            ;;
        -r | --restore)
            RESTORE=true
            ;;
        --cml-identify)
            echo "$IS_CONNECTOR#$VIRL_VERSION#$HOSTNAME"
            exit 0
            ;;
        -p | --port)
            shift
            ssh_port=$1
            ;;
        -u | --user)
            shift
            sysadmin_user=$1
            ;;
        --stop)
            if check_cml_versions; then
                stop_cml_services
            fi
            exit $?
            ;;
        --start)
            if check_cml_versions; then
                restart_cml_services
            fi
            exit $?
            ;;
        --prepare-export)
            # Runs on the source host; the initiator captures the path.
            WORKING_DIR=$(mktemp -d /var/tmp/migration.XXXXX)
            prep_rc=0
            if check_cml_versions; then
                prepare_export || prep_rc=$?
            else
                prep_rc=$?
            fi
            if [[ $prep_rc != 0 ]]; then
                rm -rf "$WORKING_DIR"
                exit "$prep_rc"
            fi
            echo "PREPARE_EXPORT_PATH=$WORKING_DIR"
            exit "$prep_rc"
            ;;
        --no-confirm)
            NO_CONFIRM=true
            ;;
        -v | --version)
            echo "$_VERSION"
            exit 0
            ;;
        --update)
            check_for_updates
            exit $?
            ;;
        --)
            shift
            break
            ;;
    esac
    shift
done

if [[ -n "$REMOTE_HOST" && -n "$BACKUP_FILE" ]]; then
    echo "Only one of --host or --file may be specified."
    exit 1
fi

if [[ -z "$REMOTE_HOST" && -z "$BACKUP_FILE" ]]; then
    echo "One of --host or --file must be specified."
    exit 1
fi

if [[ -z "$WORKING_DIR" ]]; then
    WORKING_DIR=$(mktemp -d /var/tmp/migration.XXXXX)
fi

rc=0
if [[ -n "$REMOTE_HOST" ]]; then
    sync_from_host "$REMOTE_HOST" || rc=$?
    cleanup_local
    exit $rc
fi

if [[ "$BACKUP" == "$RESTORE" ]]; then
    echo "Exactly one of --backup or --restore must be specified."
    exit 1
fi

if $RESTORE; then
    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo "Backup file $BACKUP_FILE does not exist or is not a file."
        exit 1
    fi

    # While not all data may go to the product root, the way CML's file system
    # is laid out means it's almost certainly going to be on the same FS.
    if ! check_disk_space "$BASE_DIR" "$DU" "$BACKUP_FILE"; then
        exit 1
    fi

    ask_confirm "Do you wish to restore from $BACKUP_FILE?  This will replace current local data" "restore"

    # First, extract /PRODUCT from the backup and check that the version matches the current version.
    echo "Checking source archive..."
    mkdir -p "$WORKING_DIR"
    output=$(
        tar -C "$WORKING_DIR" --occurrence=1 --acls --selinux \
            --transform="s|^MIGRATION/||" -xpf "$BACKUP_FILE" PRODUCT "MIGRATION/$CFG_FILE" 2>&1
    ) || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to extract metadata from backup:"
        printf '%s\n\n' "$output"
        exit $rc
    fi

    virl_version=$(set_virl_version "$WORKING_DIR/PRODUCT")
    is_connector=$(sed -n -e '/^IS_CONNECTOR/{s/[^01]//gp;q}' "$WORKING_DIR/$CFG_FILE")
    if check_cml_versions "$virl_version" && check_cml_is_connector "$is_connector"; then
        echo "Preliminary checks pass."
    else
        cleanup_local
        exit 1
    fi

    echo "Preparing this host..."
    prepare_local || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to prepare before extraction"
        exit $rc
    fi
    find "${SRC_DIRS[@]}" -xdev -mindepth 1 "!" -name "$IOL_RUNNER" -delete || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Failed to clean up local directories."
    fi
    mkdir -p "$IMG_DIR/at"
    chown virl2:virl2 "$IMG_DIR/at"

    trap cleanup_failed_restore SIGINT ERR

    echo "Extracting $BACKUP_FILE to local CML.  Please be patient, this may take a while..."
    total=$(du -shc "$BACKUP_FILE" -B10k --apparent-size | tail -1 | cut -f1)
    export total

    tar -C / --overwrite --acls --selinux --exclude=PRODUCT \
        --checkpoint=2000 --checkpoint-action=exec="$tar_checkpoint_action" \
        --transform="s|^MIGRATION|${WORKING_DIR#/}|" -xvpf "$BACKUP_FILE" || rc=$?
    if [[ $rc != 0 ]]; then
        echo "Extraction failed with error.  See output above for the error details."
    else
        echo -e "\nExtraction completed SUCCESSFULLY.\n"
        perform_restore
    fi

    trap - SIGINT ERR
    restart_cml_services
    cleanup_local

    exit $rc
fi

# Doing Backup

BACKUP_FILE=$(realpath "$BACKUP_FILE")

if [[ -e "$BACKUP_FILE" ]]; then
    echo "The backup file $BACKUP_FILE already exists. Please remove it or use another filename."
    exit 1
fi

# We are doing a dump to a single tar file.
if ! check_disk_space "$(dirname "$BACKUP_FILE")" "$DU" "${SRC_DIRS[@]}"; then
    exit 1
fi
# Check if we can back this up
if ! check_cml_versions; then
    exit 1
fi

ask_confirm "Are you sure you want to backup to $BACKUP_FILE?  This will restart CML services" "backup"

# Before stopping the services, fetch the diagnostics and put it in a folder to include in the backup.
if [[ "$IS_CONNECTOR" == 1 ]]; then
    /usr/bin/curl -sk ip6-localhost:8001/api/internal/diagnostics >"$CFG_DIR/diagnostics-$TIMESTAMP.log" || true
fi

rc=0
stop_cml_services || rc=$?
if [[ $rc != 0 ]]; then
    echo "Failed to stop CML services."
    exit $rc
fi

trap cleanup_backup SIGINT ERR

prepare_export
SRC_DIRS+=("$WORKING_DIR")

echo "Backing up CML data to $BACKUP_FILE.  Please be patient, this may take a while..."
total=$(du -shc /PRODUCT "${SRC_DIRS[@]}" -B10k --apparent-size | tail -1 | cut -f1)
export total

tar -C "$WORKING_DIR" --acls --selinux "${EXCLUDES[@]}" \
    --checkpoint=2000 --checkpoint-action=exec="$tar_checkpoint_action" \
    --transform="s|^${WORKING_DIR#/}|MIGRATION|" -cvpf "$BACKUP_FILE" /PRODUCT "${SRC_DIRS[@]}" || rc=$?
if [[ $rc != 0 ]]; then
    echo
    echo "Backup completed with errors.  See the output above for the error details."
else
    echo
    echo "Backup completed SUCCESSFULLY.  Backup file is $BACKUP_FILE."
fi

cleanup_backup
