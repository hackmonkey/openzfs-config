#!/usr/bin/env bash

# Create key file for encryption
KEYFILE="/dev/shm/openzfs.key"

sudo touch "${KEYFILE}" || exit
sudo chmod u=rw,go= "${KEYFILE}" || exit
printf "Enter password to open ZFS file systems: "
(
    {
        read -rs password
        printf '%s' "${password}" | sudo tee "${KEYFILE}" || exit
    } > /dev/null 2>&1
)

echo ""
echo ""
echo ""
echo "Keyfile created!"
echo ""
ls -l "${KEYFILE}"
echo ""
echo "To load into memory manually: "
echo ""
echo "    sudo zfs load-key pool-1/encrypted"
echo ""
echo "To mount all zfs file systems, after the key is loaded:"
echo ""
echo "    sudo zfs mount -a"
echo ""
