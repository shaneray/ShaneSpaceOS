#!/bin/bash -e

CONFIG_DIR="$(realpath ./)"

# extract icons
tar -zxvf includes.chroot/usr/share/icons/Windows-10.tar.gz -C includes.chroot/usr/share/icons/
rm includes.chroot/usr/share/icons/Windows-10.tar.gz

# add symbolic links
ln -sf ${ROOTFS_DIR}/usr/share/graphics/logo_shanespaceos.png ${CONFIG_DIR}/includes.installer/usr/share/graphics/logo_installer.png
ln -sf ${ROOTFS_DIR}/usr/share/graphics/logo_shanespaceos_dark.png ${CONFIG_DIR}/includes.installer/usr/share/graphics/logo_installer_dark.png
ln -sf ${ROOTFS_DIR}/lib/conky/themes/fancy.conf ${CONFIG_DIR}/includes.chroot/etc/skel/.conkyrc 

# copy skel to root
cp -rT includes.chroot/etc/skel includes.chroot/root

# copy files
echo "[Copying Files]: includes.chroot"
cp -r includes.chroot/* "${ROOTFS_DIR}"

# run hooks
for file in hooks/live/*
do
	echo "[Executing Hook]: $file"
	on_chroot "$(cat $file)"
done