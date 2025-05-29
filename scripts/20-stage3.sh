#!/bin/bash
set -euo pipefail # paranoia
# Build a stage 3 toolchain (calls ./libexec/as_chroot.sh)

# shellcheck disable=2086,2164,1091,2046

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

mkdir -pv   "$LFS"/{dev,proc,sys,run}

mount -v --bind  /dev                      "$LFS/dev"
mount -vt devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
mount -vt proc   proc                      "$LFS/proc"
mount -vt sysfs  sysfs                     "$LFS/sys"
mount -vt tmpfs  tmpfs                     "$LFS/run"

if [ -h "$LFS/dev/shm" ]; then
  install -vdm 1777 "$LFS$(realpath /dev/shm)"
else
  mount -vt tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"
fi

cp -vf "$ENVS/build.env" "$LFS/build.env"
install -vm755 "$SCRIPT_DIR/libexec/as_chroot.sh" "$LFS/as_chroot.sh"

chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    MAKEFLAGS="-j$(nproc)"      \
    TESTSUITEFLAGS="-j$(nproc)" \
    /as_chroot.sh              ||
die "Something failed in chroot" 7

# Unmount virtual kernel file systems
umount -v "$LFS/dev/shm" || true
umount -v "$LFS/dev/pts"
umount -v "$LFS/"{sys,proc,run,dev}

msg "Exited LFS chroot"

# Paranoia
if [[ ! -e "$LFS/good" ]]; then
    die "Detected a failure in LFS chroot"
fi
rm -vf "$LFS/good"
