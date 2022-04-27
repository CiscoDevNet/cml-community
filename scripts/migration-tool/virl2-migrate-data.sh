#!/bin/bash
#
#  This file is part of VIRL2
#  Cisco (c) 2021
#

source /etc/default/virl2

# Version of this script in semver 2.0 format.
_VERSION="2.0.1"

# The branch from which to grab the canonical, stable latest version of the script.
GITHUB_BRANCH="master"

# This is the link to the raw GitHub source for the script itself.
GITHUB_URL="https://raw.githubusercontent.com/CiscoDevNet/cml-community/${GITHUB_BRANCH}/scripts/migration-tool/virl2-migrate-data.sh"

SRC_DIRS="${BASE_DIR}/images ${CFG_DIR}"
KEY_FILE="migration_key"
SSH_PORT="1122"
DOING_MIGRATION=0
DEFAULT_USER="sysadmin"
MIGRATION_MAP="/var/lib/libvirt/images:${LIBVIRT_IMAGES}"

check_for_updates() {
    gh_version=$(curl -s ${GITHUB_URL} | grep "^_VERSION")
    if [ -z "${gh_version}" ]; then
        echo "Unable to find version from GitHub source.  Not updating."
        return 1
    fi

    gh_version="_GH${gh_version}"
    eval "${gh_version}"

    if [ "${_GH_VERSION}" = "${_VERSION}" ]; then
        echo "GitHub source version is the same as the current version.  Not updating."
        return 0
    fi

    curl -s --output ${LOCAL_ME} ${GITHUB_URL}
    rc=$?
    if [ ${rc} != 0 ]; then
        echo "Failed to download GitHub source.  Not updating."
        return ${rc}
    fi

    chmod +x ${LOCAL_ME}

    echo "Successfully updated to ${_GH_VERSION}.  Please re-run ${LOCAL_ME}."

    return 0
}

cleanup_backup() {
    echo
    echo "Cleaning up..."
    echo

    if [ -n "${tempd}" ]; then
        rm -rf "${tempd}"
    fi
    if [ -n "${ddir}" ]; then
        rm -rf "${ddir}"
    fi
    if [ -n "${ndir}" ]; then
        rm -rf "${ndir}"
    fi
    if [ -n "${idir}" ]; then
        rm -rf "${idir}"
    fi

    if [ ${DOING_MIGRATION} -eq 1 ]; then
        umount_refplat_overlay 2>/dev/null
    fi

    restart_cml_services

    if [ -z "${rc}" ]; then
        rc=1
    fi

    if [ ${rc} != 0 ]; then
        rm -f "${BACKUP_FILE}"
    fi

    exit ${rc}
}

cleanup_failed_restore() {
    echo
    echo "Cleaning up..."
    echo

    if [ -n "${backup_dir}" ]; then
        rm -rf "${backup_ddir}"
    fi
    if [ -n "${ddir}" ]; then
        rm -rf "${ddir}"
    fi
    if [ -n "${ndir}" ]; then
        rm -rf "${ndir}"
    fi
    if [ -n "${idir}" ]; then
        rm -rf "${idir}"
    fi

    restart_cml_services

    if [ -z "${rc}" ]; then
        rc=1
    fi

    exit ${rc}
}

cleanup_failed_from_host() {
    echo
    echo "Cleaning up..."
    echo

    if [ ${DOING_MIGRATION} -eq 1 ]; then
        ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} --umount-overlay"
    fi

    ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} --start && sudo rm -rf ${libvirt_domains} && sudo rm -f /tmp/${ME} && sudo rm -f /etc/sudoers.d/cml-migrate && (cp -fa ~/.ssh/authorized_keys.migration ~/.ssh/authorized_keys >/dev/null 2>&1 || true)"

    if [ -z "${rc}" ]; then
        rc=1
    fi

    cleanup_from_host "${key_dir}"

    exit ${rc}
}

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

needs_overlay() {
    major_ver=$(echo ${VIRL_VERSION} | cut -d'.' -f1)
    minor_ver=$(echo ${VIRL_VERSION} | cut -d'.' -f2)
    if [ "${major_ver}" -gt 2 ] || ([ "${major_ver}" -eq 2 ] && [ "${minor_ver}" -ge 3 ]); then
        return 1
    fi

    return 0
}

mount_refplat_overlay() {
    if ! needs_overlay; then
        return 0
    fi

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
    if ! needs_overlay; then
        return 0
    fi

    umount ${LIBVIRT_IMAGES}
    return $?
}

build_local_src_dirs() {
    if [ ${DOING_MIGRATION} -eq 1 ]; then
        return
    fi

    # In CML 2.3+ we no longer have the overlay.
    if ! needs_overlay; then
        SRC_DIRS="${SRC_DIRS} ${LIBVIRT_IMAGES}"
        return
    fi

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
    new_node_defs=$(find "${WRKDIR}"/node-definitions/ -maxdepth 1 -type f -name "*.yaml")
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
        echo "${ddir}"
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

export_libvirt_networks() {
    ndir=$(mktemp -d /tmp/libvirt_networks.XXXXX)
    networks=$(virsh net-list --all --name | grep -v "^default")
    if [ $? != 0 ]; then
        echo "${ndir}"
        return $?
    fi

    old_IFS=${IFS}
    IFS='
'

    for network in ${networks}; do
        virsh net-dumpxml "${network}" >"${ndir}"/"${network}".xml
    done

    IFS=${old_IFS}

    echo "${ndir}"
}

export_libvirt_ifaces() {
    idir=$(mktemp -d /tmp/libvirt_ifaces.XXXXX)
    ifaces=$(virsh net-list --all | grep "^[[:space:]]*bridge" | awk '{print $1}' | grep -v "^bridge0")
    if [ $? != 0 ]; then
        echo "${idir}"
        return $?
    fi

    old_IFS=${IFS}
    IFS='
'

    for iface in ${ifaces}; do
        virsh iface-dumpxml "${iface}" --inactive >"${idir}"/"${iface}".xml
    done

    IFS=${old_IFS}

    echo "${idir}"
}

define_domains() {
    ddir=$1

    if [ ! -d "${ddir}" ]; then
        echo "${ddir}: No such directory"
        return 1
    fi

    ls -1 "${ddir}"/*.xml >/dev/null 2>&1
    if [ $? != 0 ]; then
        return 0
    fi

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

define_networks() {
    ndir=$1

    if [ ! -d "${ndir}" ]; then
        echo "${ndir}: No such directory"
        return 1
    fi

    ls -1 "${ndir}"/*.xml >/dev/null 2>&1
    if [ $? != 0 ]; then
        return 0
    fi

    old_IFS=${IFS}
    IFS='
'

    for network in "${ndir}"/*.xml; do
        virsh net-define "${network}"
        if [ $? != 0 ]; then
            rc=$?
            IFS=${old_IFS}
            return ${rc}
        fi
    done

    IFS=${old_IFS}
}

define_ifaces() {
    idir=$1

    if [ ! -d "${idir}" ]; then
        echo "${idir}: No such directory"
        return 1
    fi

    ls -1 "${idir}"/*.xml >/dev/null 2>&1
    if [ $? != 0 ]; then
        return 0
    fi

    old_IFS=${IFS}
    IFS='
'

    for iface in "${idir}"/*.xml; do
        virsh iface-define "${iface}"
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

delete_libvirt_networks() {
    for network in $(virsh net-list --all --name | grep -v "^default"); do
        virsh net-undefine "${network}" >/dev/null
    done
}

delete_libvirt_ifaces() {
    for iface in $(virsh iface-list --all | grep "^[[:space:]]*bridge" | awk '{print $1}' | grep -v "^bridge0"); do
        virsh iface-undefine "${iface}" >/dev/null
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
    #wait_for_vms_to_stop
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

delete_local_dirs() {
    dirs=$1

    from=""
    if [ $# -ge 2 ]; then
        from=$2
    fi

    for dir in ${dirs}; do
        echo "Deleting local directory ${from}${dir}"
        rm -rf "${from}""${dir}"
        if [ $# -lt 3 ]; then
            echo "Creating directory ${from}${dir}"
            mkdir -p "${from}""${dir}"
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

    rm -rf "${key_dir}"
    restart_cml_services
}

check_cml_versions() {
    curr_ver=$1
    src_ver=$2

    if [ "${curr_ver}" = "${src_ver}" ]; then
        return 0
    fi

    # Allow one to migrate from 2.2.x to 2.3+.
    if echo "${curr_ver}" | grep -qE '^2\.[34]\.[0-9]' && echo ${src_ver} | grep -qE '^2\.2\.'; then
        DOING_MIGRATION=1
        return 0
    fi

    return 1
}

sync_from_host() {
    host=$1

    host_ip="${host}"
    if echo "${host_ip}" | grep -qE '[a-zA-Z]'; then
        host_ip=$(host -t A "${host_ip}" | grep -oE '[0-9][0-9.]+')
        if [ $? != 0 ]; then
            echo "Failed to lookup host ${host}.  Please specify a valid IP or hostname."
            return 1
        fi
    fi
    if ip addr show | grep -q "inet ${host_ip}/"; then
        echo "You are trying to migrate from the local host.  Please specify another host from which to migrate."
        return 1
    fi

    if ! nc -z "${host}" ${SSH_PORT}; then
        echo "Remote host does not have OpenSSH enabled; start the OpenSSH service from Cockpit on the source host."
        return 1
    fi

    if [ ${NO_CONFIRM} -eq 0 ]; then
        read -r -p "Do you wish to import data from ${host}? [y/N] " confirm
        echo
        if echo "${confirm}" | grep -viq '^y'; then
            echo "Terminating import."
            return 0
        fi
    fi

    stop_cml_services || (
        echo "Failed to stop CML services."
        exit $?
    )
    delete_libvirt_domains
    delete_libvirt_networks
    delete_libvirt_ifaces

    key_dir=$(generate_ssh_key)
    key=$(cat "${key_dir}"/${KEY_FILE}.pub)

    printf "\nThe next prompt will be for %s's password on %s.\n" "${sysadmin_user}" "${host}"
    printf "The prompt following that will be for %s's password on %s to enter sudo mode.\n\n" "${sysadmin_user}" "${host}"
    # Stop the service on the remote host and make sure we don't need
    # a password for sudo.  We also install the SSH pubkey for subsequent logins.
    if ! ssh -o "StrictHostKeyChecking=no" -t -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "echo '%${sysadmin_user}        ALL=(ALL)       NOPASSWD: ALL' | sudo tee /etc/sudoers.d/cml-migrate >/dev/null 2>&1 && mkdir -p ~/.ssh && \
        chmod 0700 ~/.ssh && (cp -fa ~/.ssh/authorized_keys ~/.ssh/authorized_keys.migration >/dev/null 2>&1 || true) && echo ${key} | tee -a ~/.ssh/authorized_keys >/dev/null 2>&1 && chmod 0600 ~/.ssh/authorized_keys"; then
        rc=$?
        cleanup_from_host "${key_dir}"
        echo "Error preparing ${host} for migration."
        return ${rc}
    fi

    # Install this script on the remote host.
    if ! scp -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -P ${SSH_PORT} "${LOCAL_ME}" "${sysadmin_user}"@"${host}":"/tmp/${ME}" >/dev/null; then
        rc=$?
        cleanup_from_host "${key_dir}"
        echo "Error copying /usr/local/bin/${ME} to source host."
        return ${rc}
    fi

    # Stop CML services on remote host.
    if ! ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo chmod +x /tmp/${ME} && sudo /tmp/${ME} --stop" 2>/dev/null; then
        rc=$?
        cleanup_from_host "${key_dir}"
        echo "Failed to stop source CML services."
        return ${rc}
    fi

    trap cleanup_failed_from_host SIGINT

    # Check CML versions on both hosts.
    output=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} --cml-version") 2>/dev/null)
    if [ $? != 0 ]; then
        rc=$?
        cleanup_from_host "${key_dir}"
        echo "Failed to determine remote CML version."
        return ${rc}
    fi

    if ! check_cml_versions ${VIRL_VERSION} ${output}; then
        cleanup_from_host "${key_dir}"
        echo "Migration between versions is not supported.  Source server version: ${output}, Dest server version: ${VIRL_VERSION}."
        return 1
    fi

    if [ ${DOING_MIGRATION} -eq 1 ]; then
        (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} --mount-overlay") 2>/dev/null
        if [ $? != 0 ]; then
            rc=$?
            cleanup_from_host "${key_dir}"
            return ${rc}
        fi
    fi

    migr_arg=""
    if [ ${DOING_MIGRATION} -eq 1 ]; then
        migr_arg="--migration"
    fi
    # Build the list of remote src dirs.
    output=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} ${migr_arg} --src-dirs") 2>/dev/null)
    if [ $? != 0 ]; then
        rc=$?
        cleanup_from_host "${key_dir}"
        echo "Failed to obtain remote src dirs."
        return ${rc}
    fi

    SRC_DIRS=${output}
    delete_local_dirs "${SRC_DIRS}"

    # Get the list of domains from virsh.
    libvirt_domains=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} --get-domains") 2>/dev/null)
    if [ $? != 0 ]; then
        rc=$?
        cleanup_from_host "${key_dir}"
        echo "Failed to get libvirt domains from ${host}: ${libvirt_domains}"
        return ${rc}
    fi

    # Get the list of networks from virsh
    libvirt_networks=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} --get-networks") 2>/dev/null)
    if [ $? != 0 ]; then
        rc=$?
        cleanup_from_host "${key_dir}"
        echo "Failed to get libvirt networks from ${host}: ${libvirt_networks}"
        return ${rc}
    fi

    # Get the list of ifaces from virsh
    libvirt_ifaces=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} --get-ifaces") 2>/dev/null)
    if [ $? != 0 ]; then
        rc=$?
        cleanup_from_host "${key_dir}"
        echo "Failed to get libvirt ifaces from ${host}: ${libvirt_ifaces}"
        return ${rc}
    fi

    SRC_DIRS="${SRC_DIRS} ${libvirt_domains} ${libvirt_networks} ${libvirt_ifaces}"

    echo "Migrating ${SRC_DIRS} to this CML server..."
    space_dirs=""
    if [ ${DOING_MIGRATION} -eq 1 ]; then
        for map_dir in ${MIGRATION_MAP}; do
            space_dirs="${space_dirs} $(echo "${map_dir}" | cut -d':' -f1)"
        done
    fi

    # Get required disk space from remote host
    output=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo du -B1 -sc ${SRC_DIRS} ${space_dirs} | grep total | sed -E -s 's|\s+total||'") 2>/dev/null)
    if check_disk_space "" ${BASE_DIR} "${output}"; then
        printf "Starting migration.  Please be patient, migration may take a while....\n\n\n"
        sdirs=""
        for src_dir in ${SRC_DIRS}; do
            sdirs="${sdirs} ${sysadmin_user}@${host}:${src_dir}"
        done
        rsync -aAvzXR --progress --checksum --rsync-path="sudo rsync" --exclude="*.rej" --exclude="*.orig" -e "ssh -o StrictHostKeyChecking=no -i ${key_dir}/${KEY_FILE} -p ${SSH_PORT}" ${sdirs} /
        #        output=$( (ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} sysadmin@"${host}" "sudo tar --acls --selinux -cpf - ${SRC_DIRS}" | tar -C / --acls --selinux -xpf -) 2>&1 )
        rc=$?
        if [ ${rc} != 0 ]; then
            echo "Migration completed with errors.  See the output above for details."
        else
            # Migrate each mapped src dir to its target dir.
            success=1
            if [ ${DOING_MIGRATION} -eq 1 ]; then
                for map_dir in ${MIGRATION_MAP}; do
                    src_dir=${sysadmin_user}@${host}:$(echo "${map_dir}" | cut -d':' -f1)
                    dest_dir=$(dirname $(echo "${map_dir}" | cut -d':' -f2))
                    delete_local_dirs "$(echo "${map_dir}" | cut -d':' -f2)"
                    rsync -aAvzX --progress --checksum --rsync-path="sudo rsync" --exclude="*.rej" --exclude="*.orig" -e "ssh -o StrictHostKeyChecking=no -i ${key_dir}/${KEY_FILE} -p ${SSH_PORT}" "${src_dir}" "${dest_dir}"
                    rc=$?
                    if [ ${rc} != 0 ]; then
                        echo "Migration completed with errors.  See the output above for details."
                        success=0
                        break
                    fi
                done
            fi
            if [ ${success} = 1 ]; then
                if [ ${DOING_MIGRATION} -eq 0 ]; then
                    # For each of the libvirt domains, migrate the XML.
                    echo "Migrating libvirt domains..."
                    output=$(define_domains "${libvirt_domains}" 2>&1)
                    rc=$?
                    echo "Libvirt domain output is '${output}'"
                    if [ ${rc} != 0 ]; then
                        echo "Libvirt domain import completed with errors:"
                        printf '%s\n\n' "${output}"
                    else
                        # For each of the libvirt networks, migrate the XML.
                        echo "Migrating libvirt networks..."
                        output=$(define_networks "${libvirt_networks}" 2>&1)
                        rc=$?
                        echo "Libvirt network output is '${output}'"
                        if [ ${rc} != 0 ]; then
                            echo "Libvirt network import completed with errors:"
                            printf '%s\n\n' "${output}"
                        else
                            # For each of the libvirt ifaces, migrate the XML.
                            echo "Migrating libvirt ifaces..."
                            output=$(define_ifaces "${libvirt_ifaces}" 2>&1)
                            rc=$?
                            echo "Libvirt iface output is '${output}'"
                            if [ ${rc} != 0 ]; then
                                echo "Libvirt network import completed with errors:"
                                printf '%s\n\n' "${output}"
                            else
                                echo "Migration completed SUCCESSFULLY."
                                echo "Please make sure you have either mounted the same refplat ISO on or copied its contents to this CML server."
                            fi
                        fi
                    fi
                else
                    printf "\nData transfer completed SUCCESSFULLY.\n"
                    echo "Performing configuration migration..."
                    output=$( (cd "${BASE_DIR}"/db_migrations && env CFG_DIR="${CFG_DIR}" BASE_DIR="${BASE_DIR}" VIRL2_DIR="${BASE_DIR}" HOME="${BASE_DIR}" MIGRATION_LIBVIRT_DOM_XML_DIR="${libvirt_domains}" MIGRATION_LIBVIRT_NET_XML_DIR="${libvirt_networks}" MIGRATION_LIBVIRT_IF_XML_DIR="${libvirt_ifaces}" "${BASE_DIR}"/.local/bin/alembic upgrade 2.3.0) 2>&1)
                    rc=$?
                    # This feels hacky, but we need to do it.
                    chown -R www-data:www-data "${CFG_DIR}"
                    find "${BASE_DIR}"/images -type f \( -name "*.img" -or -name "nodedisk*" \) -print0 | xargs -0 chown libvirt-qemu:kvm 2>/dev/null
                    if [ ${rc} != 0 ]; then
                        echo "Failed to execute data upgrade script:"
                        printf '%s\n\n' "${output}"
                    else
                        echo "Migration completed SUCCESSFULLY."
                    fi
                fi
            fi
        fi
    else
        rc=$?
    fi

    printf "\nFinishing up with the remote host..."
    if [ ${DOING_MIGRATION} -eq 1 ]; then
        ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} --umount-overlay"
    fi

    if ! ssh -o "StrictHostKeyChecking=no" -i "${key_dir}"/${KEY_FILE} -p ${SSH_PORT} "${sysadmin_user}"@"${host}" "sudo /tmp/${ME} --start && sudo rm -rf ${libvirt_domains} && sudo rm -rf ${libvirt_networks} && sudo rm -rf ${libvirt_ifaces} && sudo rm -f /tmp/${ME} && sudo rm -f /etc/sudoers.d/cml-migrate && (cp -fa ~/.ssh/authorized_keys.migration ~/.ssh/authorized_keys >/dev/null 2>&1 || true)"; then
        printf "FAILED.\n"
        echo "Error finishing up on remote host.  Check to make sure the CML services are running on ${host}."
        rc=$?
    else
        printf "DONE.\n"
    fi

    rm -rf "${key_dir}"
    rm -rf "${libvirt_domains}"
    rm -rf "${libvirt_networks}"
    rm -rf "${libvirt_ifaces}"

    restart_cml_services

    return ${rc}
}

ME=$(basename "$0")
LOCAL_ME=$0
set_virl_version

if [ "$EUID" != 0 ]; then
    echo "This script must be run as root.  Use 'sudo' to run it."
    exit 1
fi

opts=$(getopt -o brf:h:vdu: --long host:,file:,backup,restore,cml-version,src-dirs,stop,start,get-domains,get-networks,get-ifaces,mount-overlay,umount-overlay,migration,no-confirm,user,version,update -- "$@")
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
GET_SRC_DIRS=0
NO_CONFIRM=0

sysadmin_user=${DEFAULT_USER}

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
    --cml-version)
        echo ${VIRL_VERSION}
        exit 0
        ;;
    -u | --user)
        shift
        sysadmin_user=$1
        ;;
    -d | --src-dirs)
        GET_SRC_DIRS=1
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
    --get-networks)
        export_libvirt_networks
        exit $?
        ;;
    --get-ifaces)
        export_libvirt_ifaces
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
    --no-confirm)
        NO_CONFIRM=1
        ;;
    -v | --version)
        echo "${_VERSION}"
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

if [ ${GET_SRC_DIRS} -eq 1 ]; then
    build_local_src_dirs
    echo ${SRC_DIRS}
    exit 0
fi

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

    if [ ${NO_CONFIRM} -eq 0 ]; then
        read -r -p "Do you wish to restore from ${BACKUP_FILE}?  This will overwrite current local data. [y/N] " confirm
        echo
        if echo "${confirm}" | grep -qiv '^y'; then
            echo "Terminating restore."
            exit 0
        fi
    fi

    # First, extract /PRODUCT from the backup and check that the version matches the current version.
    tempd=$(mktemp -d /tmp/migration.XXXXX)
    output=$(tar -C "${tempd}" --acls --selinux -xpf "${BACKUP_FILE}" PRODUCT libvirt_domains.dat libvirt_networks.dat libvirt_ifaces.dat 2>&1)
    rc=$?
    if [ ${rc} != 0 ]; then
        echo "Failed to extract /PRODUCT and libvirt data from backup:"
        printf '%s\n\n' "${output}"
        exit ${rc}
    fi

    virl_version=$(set_virl_version "${tempd}"/PRODUCT)
    # This will set DOING_MIGRATION if needed.
    if ! check_cml_versions ${VIRL_VERSION} "${virl_version}"; then
        rm -rf "${tempd}"
        echo "Versions do not match or migration path not supported.  Source server version: ${virl_version}, Dest server version: ${VIRL_VERSION}."
        exit 1
    fi

    ddir=$(cat "${tempd}"/libvirt_domains.dat)
    ndir=$(cat "${tempd}"/libvirt_networks.dat)
    idir=$(cat "${tempd}"/libvirt_ifaces.dat)

    rm -rf "${tempd}"

    stop_cml_services || (
        echo "Failed to stop CML services."
        exit $?
    )
    delete_libvirt_domains
    delete_libvirt_networks
    delete_libvirt_ifaces

    trap cleanup_failed_restore SIGINT

    echo "Restoring ${BACKUP_FILE} to local CML.  Please be patient, this may take a while..."
    sdirs=""
    if [ ${DOING_MIGRATION} -eq 1 ]; then
        for sdir in ${SRC_DIRS}; do
            # Remove the leading '/' to match what's in the tar file.
            sdirs="${sdirs} $(echo "${sdir}" | cut -d'/' -f2-)"
        done
        # Add the directory that contains the libvirt domains.
        sdirs="${sdirs} $(echo "${ddir}" | cut -d'/' -f2-)"
        # Add the directory that contains the libvirt networks.
        sdirs="${sdirs} $(echo "${ndir}" | cut -d'/' -f2-)"
        # Add the directory that contains the libvirt ifaces.
        sdirs="${sdirs} $(echo "${idir}" | cut -d'/' -f2-)"
        echo "Extracting ${sdirs} from the backup..."
    fi

    delete_local_dirs "$(tar -tf "${BACKUP_FILE}" | grep '/$')" "/" 0
    export total=$(du -shc ${BACKUP_FILE} -B10k --apparent-size | tail -1 | cut -f1)
    tar -C / --acls --selinux --checkpoint=2000 --checkpoint-action=exec=' printf "\e[1;31m%s of %s extracted  %d/100%% complete  \e[0m\r" $(numfmt --to=iec-i $((10000*${TAR_CHECKPOINT})) ) $(numfmt --to=iec-i $((10000*${total})) )\t$((100*${TAR_CHECKPOINT}/${total})) ' --exclude=PRODUCT --exclude="libvirt*.dat" -xvpf "${BACKUP_FILE}"
    rc=$?
    if [ ${rc} != 0 ]; then
        echo "Restore failed with error.  See output above for the error details."
    else
        if [ ${DOING_MIGRATION} -eq 1 ]; then
            printf "\nRestore completed SUCCESSFULLY.\n"
            echo "Performing configuration migration..."
            output=$( (cd "${BASE_DIR}"/db_migrations && env CFG_DIR="${CFG_DIR}" BASE_DIR="${BASE_DIR}" VIRL2_DIR="${BASE_DIR}" HOME="${BASE_DIR}" MIGRATION_LIBVIRT_DOM_XML_DIR="${ddir}" MIGRATION_LIBVIRT_NET_XML_DIR="${ndir}" MIGRATION_LIBVIRT_IF_XML_DIR="${idir}" "${BASE_DIR}"/.local/bin/alembic upgrade 2.3.0) 2>&1)
            rc=$?
            # This feels hacky, but we need to do it.
            chown -R www-data:www-data "${CFG_DIR}"
            find "${BASE_DIR}"/images -type f \( -name "*.img" -or -name "nodedisk*" \) -print0 | xargs -0 chown libvirt-qemu:kvm 2>/dev/null
            if [ ${rc} != 0 ]; then
                echo "Failed to execute data upgrade script:"
                printf '%s\n\n' "${output}"
            else
                echo "Migration completed SUCCESSFULLY."
            fi
        else
            output=$(define_domains "${ddir}" 2>&1)
            rc=$?
            if [ ${rc} != 0 ]; then
                echo "Libvirt domain import completed with errors:"
                printf '%s\n\n' "${output}"
            else
                output=$(define_networks "${ndir}" 2>&1)
                rc=$?
                if [ ${rc} != 0 ]; then
                    echo "Libvirt network import completed with errors:"
                    printf '%s\n\n' "${output}"
                else
                    output=$(define_ifaces "${idir}" 2>&1)
                    rc=$?
                    if [ ${rc} != 0 ]; then
                        echo "Libvirt iface import completed with errors:"
                        printf '%s\n\n' "${output}"
                    else
                        echo "Restore completed SUCCESSFULLY."
                        echo "Please make sure you have either mounted the same refplat ISO on or copied its contents to this CML server."
                    fi
                fi
            fi
        fi
    fi

    rm -rf "${ddir}"
    rm -rf "${ndir}"
    rm -rf "${idir}"

    restart_cml_services

    exit ${rc}
fi

if [ ${DOING_MIGRATION} -eq 0 ]; then
    build_local_src_dirs
else
    for mig_dir in ${MIGRATION_MAP}; do
        SRC_DIRS="${SRC_DIRS} $(echo "${mig_dir}" | cut -d':' -f1)"
    done
fi

BACKUP_FILE=$(realpath "${BACKUP_FILE}")

# We are doing a dump to a single tar file.
if ! check_disk_space "${SRC_DIRS}" "$(dirname "${BACKUP_FILE}")"; then
    exit $?
fi

if [ ${NO_CONFIRM} -eq 0 ]; then
    read -r -p "Are you sure you want to backup?  Doing so will restart the CML services. [y/N] " confirm
    echo
    if echo "${confirm}" | grep -qiv '^y'; then
        echo "Terminating backup."
        exit 0
    fi
fi

stop_cml_services || (
    echo "Failed to stop CML services."
    exit $?
)

trap cleanup_backup SIGINT

if [ ${DOING_MIGRATION} -eq 1 ]; then
    mount_refplat_overlay
    if [ $? != 0 ]; then
        exit $?
    fi
fi

ddir=$(export_libvirt_domains)
ndir=$(export_libvirt_networks)
idir=$(export_libvirt_ifaces)
tempd=$(mktemp -d /tmp/migration.XXXXX)
cd "${tempd}" || (
    echo "Failed to cd to ${tempd}"
    exit $?
)
echo "${ddir}" >libvirt_domains.dat
echo "${ndir}" >libvirt_networks.dat
echo "${idir}" >libvirt_ifaces.dat

SRC_DIRS="${SRC_DIRS} ${ddir} ${ndir} ${idir}"

echo "Backing up ${SRC_DIRS}..."

echo "Backing up CML data to ${BACKUP_FILE}.  Please be patient, this may take a while..."
export total=$(du -shc /PRODUCT ${SRC_DIRS} libvirt_domains.dat libvirt_networks.dat libvirt_ifaces.dat -B10k --apparent-size | tail -1 | cut -f1)
tar -C "${tempd}" --acls --selinux --checkpoint=2000 --exclude="*.rej" --exclude="*.orig" --checkpoint-action=exec=' printf "\e[1;31m%s of %s copied  %d/100%% complete  \e[0m\r" $(numfmt --to=iec-i $((10000*${TAR_CHECKPOINT})) ) $(numfmt --to=iec-i $((10000*${total})) )\t$((100*${TAR_CHECKPOINT}/${total})) ' -cvpf "${BACKUP_FILE}" /PRODUCT libvirt_domains.dat libvirt_networks.dat libvirt_ifaces.dat ${SRC_DIRS}
rc=$?
echo
if [ ${rc} != 0 ]; then
    echo "Backup completed with errors.  See the output above for the error details."
else
    echo "Backup completed SUCCESSFULLY.  Backup file is ${BACKUP_FILE}."
fi

cleanup_backup
