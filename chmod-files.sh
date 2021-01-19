chmod_dir="./variants/debian"
git update-index --add --chmod=+x "${chmod_dir}/auto/"*
git update-index --add --chmod=+x "${chmod_dir}/config/hooks/live/"*

chmod_dir+="/config/includes.chroot"
git update-index --add --chmod=+x "${chmod_dir}/bin/"*
git update-index --add --chmod=+x "${chmod_dir}/lib/live-build/"*
git update-index --add --chmod=+x "${chmod_dir}/lib/lsb/init-functions.d/"*
git update-index --add --chmod=+x "${chmod_dir}/lib/shanespace/install"
git update-index --add --chmod=+x "${chmod_dir}/lib/shanespace/ssbash"
git update-index --add --chmod=+x "${chmod_dir}/lib/shanespace/ssbash.d/"*
git update-index --add --chmod=+x "${chmod_dir}/usr/lib/xscreensaver/"*
git update-index --add --chmod=+x "${chmod_dir}/usr/share/initramfs-tools/scripts/init-premount/"*
git update-index --add --chmod=+x "${chmod_dir}/usr/share/templates/.source/bash-template"