#!/usr/bin/env bash
SCRIPT_PATH="$(readlink -f "${0}")"
SCRIPT_DIR="$(dirname ${SCRIPT_PATH})"

ZFS_ROOT="/zfs"
POOL_NAME="pool-1"
CONFIG_DIR="${SCRIPT_DIR}"

ZPOOL_OPTIONS_FILE="${CONFIG_DIR}/zpool-options-enabled.txt"
ZPOOL_FEATURES_FILE="${CONFIG_DIR}/zpool-features-enabled.txt"
ZPOOL_DISKS_FILE="${CONFIG_DIR}/${POOL_NAME}.disks"
ZPOOL_VDEV_TYPE="raidz2"

ZFS_SETTINGS_DIR="${CONFIG_DIR}/zfs-create"
KEYFILE="/dev/shm/openzfs.key"


"${SCRIPT_DIR}"/zfs-create-keyfile.sh


echo ""
echo "Running command: "
echo zpool create $(cat "${ZPOOL_OPTIONS_FILE}" | tr '\n' ' ') $(cat "${ZPOOL_FEATURES_FILE}" | tr '\n' ' ') -m "${ZFS_ROOT}"/"${POOL_NAME}" "${POOL_NAME}" ${ZPOOL_VDEV_TYPE} $(cat "${ZPOOL_DISKS_FILE}" | tr '\n' ' ')
zpool create $(cat "${ZPOOL_OPTIONS_FILE}" | tr '\n' ' ') $(cat "${ZPOOL_FEATURES_FILE}" | tr '\n' ' ') -m "${ZFS_ROOT}"/"${POOL_NAME}" "${POOL_NAME}" ${ZPOOL_VDEV_TYPE} $(cat "${ZPOOL_DISKS_FILE}" | tr '\n' ' ')

# create file systems
echo "File systems to create: "${ZFS_SETTINGS_DIR}"/file-systems.txt"
xargs printf "    %s\n" < "${ZFS_SETTINGS_DIR}"/file-systems.txt

function create_zfs() {
    NAME="${1}"
    echo "Creating ZFS: ${NAME}"
    zfs create -v $(cat "${ZFS_SETTINGS_DIR}"/${NAME}.settings | tr '\n' ' ') "${POOL_NAME}"/${NAME}
}

rg -v '^ *#' "${ZFS_SETTINGS_DIR}"/file-systems.txt | while IFS= read -r ZFS_NAME
do
    create_zfs "${ZFS_NAME}"
done
