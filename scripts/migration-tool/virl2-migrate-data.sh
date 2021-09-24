#!/bin/bash
#
#  This file is part of VIRL2
#  Cisco (c) 2021
#

source /etc/default/virl2

SRC_DIRS="${BASE_DIR}/images ${CFG_DIR}"
KEY_FILE="migration_key"
SSH_PORT="1122"
DOING_MIGRATION=0
MIGRATION_MAP="${LIBVIRT_IMAGES}:${LIBVIRT_IMAGES}"

set_virl_version() {
    product_file=/PRODUCT
    if [ $# = 1 ]; then
        product_file=$1
    fi

    vers=$(jq -r ".PRODUCT_VERSION" <"${product_file}")

    if [ $# = 1 ]; then
        echo ${vers}
    else
        VIRL_VERSION=${vers}
    fi
}

mount_refplat_overlay() {
    # create required directories, if needed
    [ -d $REF_PLAT/cdrom ] || mkdir -p $REF_PLAT/cdrom
    [ -d $REF_PLAT/diff ] || mkdir -p $REF_PLAT/diff
    [ -d $REF_PLAT/work ] || mkdir -p $REF_PLAT/work

    if [ $REF_PLAT != $LIBVIRT_IMAGES ]; then
        MOUNT_POINT=$REF_PLAT/cdrom
    else
        MOUNT_POINT=$LIBVIRT_IMAGES
    fi

    # if overlayfs is mounted, do nothing
    mount | grep -q "^overlay on $LIBVIRT_IMAGES"
    if [ $? -eq 0 ]; then
        return 0
    fi

    # try to mount the CDROM. If none is present it will continue
    # it will just give an error for the mount like
    # "mount: /var/local/virl2/refplat/cdrom: no medium found on /dev/sr0."
    if [ -f "$REF_PLAT_ISO_IMAGE" ]; then
        ! test -d $MOUNT_POINT && mkdir $MOUNT_POINT
        if ! mount -t iso9660 -oloop,fscontext=$CONTEXT $REF_PLAT_ISO_IMAGE $MOUNT_POINT; then
            echo "no refplat ISO image present / mounted!"
            return 1
        fi
    elif [ -d "$REF_PLAT_DIR" ]; then
        if test -d "$REF_PLAT_DIR"; then
            test -d $MOUNT_POINT && rmdir $MOUNT_POINT
            ln -s $REF_PLAT_DIR $MOUNT_POINT
        else
            echo "no refplat ISO image present / mounted!"
            return 1
        fi
    else
        ! test -d $MOUNT_POINT && mkdir $MOUNT_POINT
        if ! mount $CDROM_DEVICE; then
            echo "no refplat CD-ROM present / mounted!"
            return 1
        fi
    fi

    # mount the libvirt image directory in an OverlayFS
    if [ $REF_PLAT != $LIBVIRT_IMAGES ]; then
        mount -t overlay overlay \
            -ofscontext=$CONTEXT,lowerdir=$REF_PLAT/cdrom,upperdir=$REF_PLAT/diff,workdir=$REF_PLAT/work \
            $LIBVIRT_IMAGES
        if [ $? != 0 ]; then
            echo "error mounting overlay filesystem"
            return 1
        fi
    fi

    return 0
}

umount_refplat_overlay() {
    umount ${LIBVIRT_IMAGES}
    return $?
}

build_local_src_dirs() {
    if [ "${REF_PLAT}" != "${LIBVIRT_IMAGES}" ]; then
        MOUNT_POINT=${REF_PLAT}/cdrom
    else
        MOUNT_POINT=${LIBVIRT_IMAGES}
    fi

    if [ -d "${REF_PLAT_DIR}" ]; then
        MOUNT_POINT="${REF_PLAT_DIR}"
    fi

    WRKDIR="${REF_PLAT}"/diff

    # Find all custom node defs
    new_node_defs=$(find "${WRKDIR}"/node-definitions/ -maxdepth 1 -type f)
    old_IFS=${IFS}
    IFS='
'
    for nd in ${new_node_defs}; do
        fname=$(basename "${nd}")
        if [ ! -f "${MOUNT_POINT}"/node-definitions/"${fname}" ]; then
            SRC_DIRS="${SRC_DIRS} ${nd}"
        else
            if ! diff -q "${nd}" "${MOUNT_POINT}"/node-definitions/"${fname}" >/dev/null 2>&1; then
                SRC_DIRS="${SRC_DIRS} ${nd}"
            fi
        fi
    done

    # Find all custom image defs
    new_image_defs=$(find "${WRKDIR}"/virl-base-images/ -maxdepth 1 -type d)

    for id in ${new_image_defs}; do
        if [ "${id}" = "${WRKDIR}"/virl-base-images/ ]; then
            continue
        fi
        dname=$(basename "${id}")
        if [ ! -d "${MOUNT_POINT}"/virl-base-images/"${dname}" ]; then
            SRC_DIRS="${SRC_DIRS} ${id}"
        fi
    done

    IFS=${old_IFS}
}

export_libvirt_domains() {
    ddir=$(mktemp -d /tmp/libvirt_domains.XXXXX)
    domains=$(virsh list --all --name)
    if [ $? != 0 ]; then
        return $?
    fi

    old_IFS=${IFS}
    IFS='
'

    for domain in ${domains}; do
        virsh dumpxml "${domain}" >"${ddir}"/"${domain}".xml
    done

    IFS=${old_IFS}

    echo "${ddir}"
}

define_domains() {
    ddir=$1

    old_IFS=${IFS}
    IFS='
'

    for domain in "${ddir}"/*.xml; do
        virsh define "${domain}"
        if [ $? != 0 ]; then
            rc=$?
            IFS=${old_IFS}
            return ${rc}
        fi
    done

    IFS=${old_IFS}
}

delete_libvirt_domains() {
    for domain in $(virsh list --all --name); do
        virsh undefine "${domain}" >/dev/null
    done
}

check_disk_space() {
    source=$1
    target=$2

    if [ -z "${source}" ] && [ $# = 3 ]; then
        total_needed=$3
    else
        total_needed=$(du -B1 -sc ${source} | grep total | sed -E -s 's|\s+total||')
    fi

    total_available=$(df -B1 --output=avail "${target}" | grep -E '[0-9]')

    if [ "${total_needed}" -gt "${total_available}" ]; then
        echo "Insufficient disk space required in ${target}; ${total_needed} bytes required but only ${total_available} bytes available."
        return 1
    fi

    return 0
}

wait_for_vms_to_stop() {
    # this is only needed if VMs are running on the
    # controller where the ISO is mounted.
    loops=5 # max 5x5 = 25s
    done=0
    while ((loops > 0 && !done)); do
        done=1
        for vm in $(virsh -c qemu:///system list --all --name); do
            if [[ "$vm" =~ ^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12} ]]; then
                vm_state=$(virsh dominfo "$vm")
                if [[ "$vm_state" =~ State:\ +running ]]; then
                    echo "still running: $vm"
                    done=0
                fi
            fi
        done
        ((loops -= 1))
        ((!done)) && sleep 5
    done
    if ((!done)); then
        echo "Some labs are still running; please stop all labs before continuing"
        return 1
    fi
}

stop_cml_services() {
    wait_for_vms_to_stop
    rc=$?
    if [ ${rc} != 0 ]; then
        return ${rc}
    fi
    systemctl stop virl2.target
    rc=$?
    if [ ${rc} != 0 ]; then
        return ${rc}
    fi

    echo "Waiting for controller to become inactive..."
    while [ "$(systemctl is-active virl2-controller)" = "active" ]; do
        echo "  Still active..."
        sleep 5
    done
    return ${rc}
}

restart_cml_services() {
    echo "Restarting CML services..."
    systemctl start virl2.target
}

backup_local_files() {
    # Backup each source directory, just in case.
    # Do this with mv to avoid running out of disk space.
    for dir in ${SRC_DIRS}; do
        if [ -e "${dir}" ]; then
            rm -rf "${dir}".bak
            mv -f "${dir}" "${dir}".bak
        fi
    done
}

restore_local_files() {
    for dir in ${SRC_DIRS}; do
        if [ -e "${dir}" ]; then
            rm -rf "${dir}"
            mv -f "${dir}".bak "${dir}"
        fi
    done
}

generate_ssh_key() {
    # Generate an SSH key we can use to avoid re-prompting for a password.
    tempd=$(mktemp -d /tmp/migration.XXXXX)
    ssh-keygen -b 4096 -q -N "" -f "${tempd}"/${KEY_FILE}
    echo "${tempd}"
}

cleanup_from_host() {
    key_dir=$1
    backup_ddir=$2

    rm -rf "${key_dir}"
    restore_local_files
    define_domains "${backup_ddir}"
    restart_cml_services
    rm -rf "${backup_ddir}"
}

check_cml_versions() {
    curr_ver=$1
    src_ver=$2

    if [ "${curr_ver}" = "${src_ver}" ]; then
        return 0
    fi

    # Allow one to migrate from 2.2.x to 2.3.0.
    if echo ${curr_ver} | grep -qE '^2\.3\.0' && echo ${src_ver} | grep -qE '^2\.2\.'; then
        DOING_MIGRATION=1
        return 0
    fi

    return 1
}

sync_from_host() {
    host=$1

    if ! nc -z "${host}" ${SSH_PORT}; then
        echo "Remote host does not have OpenSSH enabled; start the OpenSSH service from Cockpit on the source host."
        return 1
    fi

    read -r -p "Do you wish to import data from ${host}? [y/N] " confirm
    echo
    if echo "${confirm}" | grep -viq '^y'; then
        echo "Terminating import."
        return 0
    fi

    stop_cml_services || (
        echo "Failed to stop CML services."
        exit $?
    )
    backup_local_files
    backup_ddir=$(export_libvirt_domains)
    delete_libvirt_domains

    key_dir=$(generate_ssh_key)
    key=$(cat "${key_dir}"/${KEY_FILE}.pub)

    printf "\nThe next prompt will be for sysadmin's password on %s.\n" "${host}"
    printf "The prompt following that will be for sysadmin's password on %s to enter sudo mode.\n\n" "${host}"
    # Stop the service on the remote host and make sure we don't need
    # a password for sudo.  We also install the SSH pubkey for subsequent logins.
    if ! ssh -o "StrictHostKeyChecking=no" -t -p ${SSH_PORT} sysadmin@"${host}" "echo '%sysadmin        ALL=(ALL)       NOPASSWD: ALL' | sudo tee /etc/sudoers.d/cml-migrate >/dev/null 2>&1 && mkdir -p ~/.ssh && \
        chmod 0700 ~/.ssh && (cp -fa ~/.ssh/authorized_keys ~/.ssh/authorized_keys.migration >/dev/null 2>&1 || true) && echo ${key} | tee -a ~/.ssh/authorized_keys >/dev/null 2>&1 && chmod 0600 ~/.ssh/authorized_keys"; then
        rc=$?
        cleanup_from_host "${key_dir}" "${backup_ddir}"
        echo "Error preparing ${host} for migration.  The original local data have been restored."
        return ${rc}
    fi

    # Install this script on the remote host.
    if ! scp -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -P ${SSH_PORT} "/usr/local/bin/${ME}" sysadmin@"${host}":"/tmp/${ME}" >/dev/null; then
        rc=$?
        cleanup_from_host "${key_dir}" "${backup_ddir}"
        echo "Error copying /usr/local/bin/${ME} to source host.  The original local data have been restored."
        return ${rc}
    fi

    # Stop CML services on remote host.
    if ! ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo chmod +x /tmp/${ME} && sudo /tmp/${ME} --stop" 2>/dev/null; then
        rc=$?
        cleanup_from_host "${key_dir}" "${backup_ddir}"
        echo "Failed to stop source CML services."
        exit ${rc}
    fi

    # Check CML versions on both hosts.
    output=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo /tmp/${ME} --version") 2>/dev/null)
    if [ $? != 0 ]; then
        rc=$?
        cleanup_from_host "${key_dir}" "${backup_ddir}"
        echo "Failed to determine remote CML version."
        exit ${rc}
    fi

    if ! check_cml_versions ${VIRL_VERSION} ${output}; then
        cleanup_from_host "${key_dir}" "${backup_ddir}"
        echo "Migration between versions is not supported.  Source server version: ${output}, Dest server version: ${VIRL_VERSION}.  The original local data has been restored."
        return 1
    fi

    if [ ${DOING_MIGRATION} -eq 1 ]; then
        (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo /tmp/${ME} --mount-overlay") 2>/dev/null
        if [ $? != 0 ]; then
            rc=$?
            cleanup_from_host "${key_dir}" "${backup_ddir}"
            exit ${rc}
        fi
    else
        # Build the list of remote src dirs.
        output=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo /tmp/${ME} --src-dirs") 2>/dev/null)
        if [ $? != 0 ]; then
            rc=$?
            cleanup_from_host "${key_dir}" "${backup_ddir}"
            echo "Failed to obtain remote src dirs."
            exit ${rc}
        fi

        SRC_DIRS=${output}
    fi

    # Get the list of domains from virsh.
    libvirt_domains=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo /tmp/${ME} --get-domains") 2>/dev/null)
    if [ $? != 0 ]; then
        rc=$?
        cleanup_from_host "${key_dir}" "${backup_ddir}"
        echo "Failed to get libvirt domains from ${host}: ${libvirt_domains}"
        exit ${rc}
    fi

    SRC_DIRS="${SRC_DIRS} ${libvirt_domains}"

    echo "Migrating ${SRC_DIRS} to this CML server..."

    # Get required disk space from remote host
    output=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo du -B1 -sc ${SRC_DIRS} | grep total | sed -E -s 's|\s+total||'") 2>/dev/null)
    if check_disk_space "" ${BASE_DIR} "${output}"; then
        printf "Starting migration.  Please be patient, migration may take a while....\n\n\n"
        sdirs=""
        for src_dir in ${SRC_DIRS}; do
            sdirs="${sdirs} sysadmin@\"${host}\":${src_dir}"
        done
        output=$( (rsync -aAvX -e "ssh -o StrictHostKeyChecking=no -i \"${key_dir}\"/${KEY_FILE} -p ${SSH_PORT}" ${sdirs} /) 2>&1)
        #        output=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo tar --acls --selinux -cpf - ${SRC_DIRS}" | tar -C / --acls --selinux -xpf -) 2>&1 )
        rc=$?
        if [ ${rc} != 0 ]; then
            restore_local_files
            define_domains "${backup_ddir}"
            echo "Migration completed with errors:"
            printf '%s\n\n' "${output}"
            echo "The original local data have been restored."
        else
            # Migrate each mapped src dir to its target dir.
            success=1
            for map_dir in ${MIGRATION_MAP}; do
                src_dir=sysadmin@"${host}":$(cut -d':' -f1)
                dest_dir=$(cut -d':' -f2)
                output=$( (rsync -aAvX -e "ssh -o StrictHostKeyChecking=no -i \"${key_dir}\"/${KEY_FILE} -p ${SSH_PORT}" ${src_dir} ${dest_dir}) 2>&1)
                rc=$?
                if [ ${rc} != 0 ]; then
                    restore_local_files
                    define_domains "${backup_ddir}"
                    echo "Migration completed with errors:"
                    printf '%s\n\n' "${output}"
                    echo "The original local data have been restored."
                    success=0
                    break
                fi
            done
            if [ ${success} = 1 ]; then
                # For each of the libvirt domains, migrate the XML.
                echo "Migrating libvirt domains..."
                output=$(define_domains "${libvirt_domains}" 2>&1)
                rc=$?
                if [ ${rc} != 0 ]; then
                    restore_local_files
                    define_domains "${backup_ddir}"
                    echo "Libvirt domain import completed with errors:"
                    printf '%s\n\n' "${output}"
                    echo "The original local data have been restored."
                else
                    echo "Migration completed SUCCESSFULLY."
                    echo "Please make sure you have either mounted the same refplat ISO on or copied its contents to this CML server."
                fi
            fi
        fi
    else
        rc=$?
    fi

    printf "\nFinishing up with the remote host..."
    if [ ${DOING_MIGRATION} -eq 1 ]; then
        ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo /tmp/${ME} --umount-overlay"
    fi

    if ! ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo /tmp/${ME} --start && sudo rm -rf ${libvirt_domains} && sudo rm -f /tmp/${ME} && sudo rm -f /etc/sudoers.d/cml-migrate && (cp -fa ~/.ssh/authorized_keys.migration ~/.ssh/authorized_keys >/dev/null 2>&1 || true)"; then
        printf "FAILED.\n"
        echo "Error finishing up on remote host.  Check to make sure the CML services are running on ${host}."
        rc=$?
    else
        printf "DONE.\n"
    fi

    rm -rf "${key_dir}"
    rm -rf "${libvirt_domains}"
    rm -rf "${backup_ddir}"

    if [ ${DOING_MIGRATION} -eq 1 ]; then
        if [ ${rc} = 0 ]; then
            output=$( (env CFG_DIR=${CFG_DIR} VIRL2_DIR=${VIRL2_DIR} HOME=${VIRL2_DIR} ${VIRL2_DIR}/.local/bin/alembic upgrade 2.3.0) 2>&1)
            rc=$?
            if [ ${rc} != 0 ]; then
                echo "Failed to execute data upgrade script:"
                printf '%s\n\n' "${output}"
            fi
        fi
    fi

    restart_cml_services

    return ${rc}
}

ME=$(basename "$0")
set_virl_version

if [ "$EUID" != 0 ]; then
    echo "This script must be run as root.  Use 'sudo' to run it."
    exit 1
fi

opts=$(getopt -o brf:h:vd --long host:,file:,backup,restore,version,src-dirs,stop,start,get-domains,mount-overlay,umount-overlay,migration -- "$@")
if [ $? != 0 ]; then
    echo "usage: $0 -h|--host HOST_TO_MIGRATE_FROM"
    echo "       OR"
    echo "       $0 -b|--backup|-r|--restore -f|--file PATH_TO_BACKUP_FILE"
    exit 1
fi

REMOTE_HOST=
BACKUP_FILE=
BACKUP=0
RESTORE=0

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
        BACKUP=1
        ;;
    -m | --migration)
        DOING_MIGRATION=1
        ;;
    -r | --restore)
        RESTORE=1
        ;;
    -v | --version)
        echo ${VIRL_VERSION}
        exit 0
        ;;
    -d | --src-dirs)
        build_local_src_dirs
        echo ${SRC_DIRS}
        exit 0
        ;;
    --stop)
        stop_cml_services
        exit $?
        ;;
    --start)
        restart_cml_services
        exit $?
        ;;
    --get-domains)
        export_libvirt_domains
        exit $?
        ;;
    --mount-overlay)
        mount_refplat_overlay
        exit $?
        ;;
    --umount-overlay)
        umount_refplat_overlay
        exit $?
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

if [ -n "${REMOTE_HOST}" ] && [ -n "${BACKUP_FILE}" ]; then
    echo "Only one of --host or --file may be specified."
    exit 1
fi

if [ -z "${REMOTE_HOST}" ] && [ -z "${BACKUP_FILE}" ]; then
    echo "One of --host or --file must be specified."
    exit 1
fi

if [ -n "${REMOTE_HOST}" ]; then
    sync_from_host "${REMOTE_HOST}"
    exit $?
fi

if [ ${BACKUP} = 1 ] && [ ${RESTORE} = 1 ]; then
    echo "Only one of --backup or --restore can be specified."
    exit 1
fi

if [ ${BACKUP} = 0 ] && [ ${RESTORE} = 0 ]; then
    echo "One of --backup or --restore must be specified."
    exit 1
fi

if [ ${RESTORE} = 1 ]; then
    if [ ! -f "${BACKUP_FILE}" ]; then
        echo "Backup file ${BACKUP_FILE} does not exist or is not a file."
        exit 1
    fi

    DOING_MIGRATION=0

    # While not all data may go to the product root, the way CML's file system
    # is laid out means it's almost certainly going to be on the same FS.
    if ! check_disk_space "${BACKUP_FILE}" ${BASE_DIR}; then
        exit $?
    fi

    read -r -p "Do you wish to restore from ${BACKUP_FILE}?  This will overwrite current local data. [y/N] " confirm
    echo
    if echo "${confirm}" | grep -qiv '^y'; then
        echo "Terminating restore."
        exit 0
    fi

    # First, extract /PRODUCT from the backup and check that the version matches the current version.
    tempd=$(mktemp -d /tmp/migration.XXXXX)
    output=$(tar -C "${tempd}" --acls --selinux -xpf "${BACKUP_FILE}" PRODUCT libvirt_domains.dat 2>&1)
    rc=$?
    if [ ${rc} != 0 ]; then
        echo "Failed to extract /PRODUCT from backup:"
        printf '%s\n\n' "${output}"
        exit ${rc}
    fi

    virl_version=$(set_virl_version "${tempd}"/PRODUCT)
    if check_cml_versions ${VIRL_VERSION} "${virl_version}"; then
        rm -rf "${tempd}"
        echo "Versions do not match or migration path not supported.  Source server version: ${virl_version}, Dest server version: ${VIRL_VERSION}."
        exit 1
    fi

    ddir=$(cat "${tempd}"/libvirt_domains.dat)

    rm -rf "${tempd}"

    stop_cml_services || (
        echo "Failed to stop CML services."
        exit $?
    )
    backup_local_files
    backup_ddir=$(export_libvirt_domains)
    delete_libvirt_domains

    echo "Restoring ${BACKUP_FILE} to local CML.  Please be patient, this may take a while..."
    output=$(tar -C / --acls --selinux --exclude=PRODUCT -xpf "${BACKUP_FILE}" ${SRC_DIRS} 2>&1)
    rc=$?
    if [ ${rc} != 0 ]; then
        restore_local_files
        define_domains "${backup_ddir}"
        echo "Restore failed with error:"
        printf '%s\n\n' "${output}"
        echo "The original local data has been restored."
    else
        output=$(define_domains "${ddir}" 2>&1)
        rc=$?
        if [ ${rc} != 0 ]; then
            echo "Libvirt domain import completed with errors:"
            printf '%s\n\n' "${output}"
            echo "The original local data have been restored."
        else
            echo "Restore completed SUCCESSFULLY."
            if [ ${DOING_MIGRATION} -eq 0 ]; then
                echo "Please make sure you have either mounted the same refplat ISO on or copied its contents to this CML server."
            fi
        fi
    fi

    rm -rf "${backup_ddir}"

    restart_cml_services

    exit ${rc}
fi

if [ ${DOING_MIGRATION} -eq 0 ]; then
    build_local_src_dirs
else
    SRC_DIRS="${SRC_DIRS} ${LIBVIRT_IMAGES}"
fi

BACKUP_FILE=$(realpath "${BACKUP_FILE}")

# We are doing a dump to a single tar file.
if ! check_disk_space "${SRC_DIRS}" "$(dirname "${BACKUP_FILE}")"; then
    exit $?
fi

read -r -p "Are you sure you want to backup?  Doing so will restart the CML services. [y/N] " confirm
echo
if echo "${confirm}" | grep -qiv '^y'; then
    echo "Terminating backup."
    exit 0
fi

stop_cml_services || (
    echo "Failed to stop CML services."
    exit $?
)

if [ ${DOING_MIGRATION} -eq 1 ]; then
    mount_refplat_overlay
    if [ $? != 0 ]; then
        exit $?
    fi
fi

ddir=$(export_libvirt_domains)
tempd=$(mktemp -d /tmp/migration.XXXXX)
cd "${tempd}"
echo "${ddir}" >libvirt_domains.dat

SRC_DIRS="${SRC_DIRS} ${ddir}"

echo "Backing up ${SRC_DIRS}..."

echo "Backing up CML data to ${BACKUP_FILE}.  Please be patient, this may take a while..."
output=$(tar -C "${tempd}" --acls --selinux -cpf "${BACKUP_FILE}" /PRODUCT ${SRC_DIRS} libvirt_domains.dat 2>&1)
rc=$?
if [ ${rc} != 0 ]; then
    rm -f "${BACKUP_FILE}"
    echo "Backup completed with errors:"
    printf '%s\n\n' "${output}"
else
    echo "Backup completed SUCCESSFULLY."
fi

rm -rf "${tempd}"
rm -rf "${ddir}"

if [ ${DOING_MIGRATION} -eq 1 ]; then
    umount_refplat_overlay
fi

restart_cml_services

exit ${rc}
