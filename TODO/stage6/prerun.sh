#!/bin/bash -e

echo "Stage 6: prerun"
if [ ! -d "${ROOTFS_DIR}" ]; then
	copy_previous
fi
