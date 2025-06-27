#!/bin/bash
set -euo pipefail
# At this point, we're into stage 3 territory. This script is run as chroot.

# shellcheck disable=2068,1091
source /build.env


# Expand the filesystem hierarchy
mkdir -pv /{boot,home,mnt,opt}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /usr/{include,src}
mkdir -pv /usr/lib/locale
mkdir -pv /usr/share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/share/man/man{1..8}
mkdir -pv /var/{cache,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

install -vdm 0750 /root
install -vdm 1777 /tmp /var/tmp


# Create essential files and symlinks
ln -sv /proc/self/mounts /etc/mtab

cat > /etc/hosts << EOF
127.0.0.1  localhost to
::1        localhost to
EOF

cat > /etc/hostname << EOF
to
EOF

cat > /etc/resolv.conf << EOF
nameserver 1.1.1.1
EOF


# Set up users and groups
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
tester:x:101:101::/home/tester:/bin/bash
EOF

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
tester:x:101:
EOF

install -o tester -d /home/tester


# Create files wanted by some utilities
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp


# Gettext
pre gettext

./configure \
    --disable-shared    \
    --disable-java      \
    --disable-d         \
    --disable-nls       \
    --disable-rpath     \
    --disable-modula2   \
    --disable-acl       \
    --disable-csharp    \
    --disable-go        \
    --without-emacs     \
    --without-git       \
    --without-bzip2
make
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin


# Bison
pre bison

./configure --prefix=/usr
make
make install


# Perl
pre perl

sh Configure -des                                         \
             -D prefix=/usr                               \
             -D vendorprefix=/usr                         \
             -D useshrplib                                \
             -D privlib=/usr/lib/perl5/5.40/core_perl     \
             -D archlib=/usr/lib/perl5/5.40/core_perl     \
             -D sitelib=/usr/lib/perl5/5.40/site_perl     \
             -D sitearch=/usr/lib/perl5/5.40/site_perl    \
             -D vendorlib=/usr/lib/perl5/5.40/vendor_perl \
             -D vendorarch=/usr/lib/perl5/5.40/vendor_perl
make
make install


# Python
pre Python

./configure --prefix=/usr           \
            --enable-shared         \
            --disable-test-modules  \
            --without-dtrace        \
            --without-valgrind      \
            --without-ensurepip     \
            --without-static-libpython
make
make install


# Texinfo
pre texinfo
./configure --prefix=/usr
make
make install


# Util-linux
pre util-linux

mkdir -pv /var/lib/hwclock

_cfg=(
    # disable obscure utils
    --disable-bfs
    --disable-cramfs
    --disable-minix
    --disable-ul
    --disable-wall
    --disable-mesg
    --disable-vdir

    # disable utils with superior alternatives
    --disable-more
    --disable-rename

    # disable utils not needed in a stage2
    --disable-cal
    --disable-fdisks
    --disable-losetup
    --disable-zramctl
    --disable-fsck
    --disable-partx
    --disable-wipefs
    --disable-nsenter
    --disable-eject
    --disable-agetty
    --disable-wdctl
    --disable-unshare
    --disable-isosize
    --disable-uclampset
    --disable-plymouth_support
    --disable-irqtop
    --disable-ionice
    --disable-ipcs
    --disable-prlimit
    --disable-taskset
    --disable-mkfs
    --disable-fstrim
    --disable-swapon
    --disable-last
    --disable-raw
    --disable-whereis # underrated util imo

    # disable generic junk
    --disable-assert
    --disable-rpath
    --disable-nls
    --disable-bash-completion
    --disable-pg-bell

    # external
    --without-udev
    --without-econf
    --without-systemd
    --without-btrfs
    --without-utempter
    --without-slang
)

./configure --libdir=/usr/lib      \
            --runstatedir=/run     \
            --disable-chfn-chsh    \
            --disable-login        \
            --disable-nologin      \
            --disable-su           \
            --disable-setpriv      \
            --disable-runuser      \
            --disable-pylibmount   \
            --disable-static       \
            --disable-liblastlog2  \
            --without-python       \
            "${_cfg[@]}"           \
            ADJTIME_PATH=/var/lib/hwclock/adjtime
make
make install


echo "CHECKPOINT: Minimal system complete" >&2
# At this point, we enter into chapter 8 (ish) of LFS
# Everything built from here isn't strictly necessary, but is good to have
#
# * Iana-etc        - Nice to have
# * Glibc           - Rebuilt for completeness
# * Zstd            - Needed by To
# * Zlib            - Dependency of Binutils
# * Flex            - Compilation convenience
# * Groff           - Compilation convenience
# * Pkgconf         - Compilation convenience
# * Binutils        - Rebuilt for completeness
# * GMP             - Dependency of GCC
# * MPFR            - Dependency of GCC
# * MPC             - Dependency of GCC
# * ISL             - Dependency of GCC
# * GCC             - Rebuilt for optimizations and completeness
# * Which           - Compilation convenience
# * Libtool         - Compilation convenience
# * Autoconf        - Compilation convenience
# * Automake        - Compilation convenience
#
sleep 2


# Iana-etc
pre iana-etc
cp services protocols /etc


# Glibc
pre glibc

patch -Np1 -i ../glibc-2.41-fhs-1.patch

mkdir -v build
cd       build

echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr                   \
             --disable-werror                \
             --disable-nscd                  \
             libc_cv_slibdir=/usr/lib        \
             --enable-stack-protector=strong \
             --enable-kernel=6.12
make

touch /etc/ld.so.conf
# shellcheck disable=2016
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

make install
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

localedef -i C -f UTF-8 C.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8

cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF


# Zstd
pre zstd

# TODO: Figure out how to disable lzma support
make prefix=/usr
make prefix=/usr install
rm -vf /usr/lib/libzstd.a


# Zlib
pre zlib
./configure --prefix=/usr
make
make install
rm -vf /usr/lib/libz.a


# Flex
pre flex
./configure --prefix=/usr       \
            --disable-static    \
            --disable-nls       \
            --disable-rpath
make
make install
ln -sv flex   /usr/bin/lex


# Groff
pre groff
PAGE=letter ./configure --prefix=/usr       \
                        --disable-rpath     \
                        --without-x         \
                        --without-uchardet
make
make install


# Pkgconf
pre pkgconf
./configure --prefix=/usr --disable-static
make
make install
ln -sv pkgconf   /usr/bin/pkg-config


# Binutils
pre binutils

mkdir -v build
cd       build

../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --enable-new-dtags  \
             --with-system-zlib  \
             --enable-default-hash-style=gnu
make tooldir=/usr
make tooldir=/usr install

rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
        /usr/share/doc/gprofng/


# GMP
pre gmp

sed '/long long t1;/,+1s/()/(...)/' -i configure
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static
make
make install


# MPFR
pre mpfr
./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe
make
make check # all 198 tests should pass
make install


# MPC
pre mpc
./configure --prefix=/usr    \
            --disable-static
make
make install


# ISL
pre isl
./configure --prefix=/usr    \
            --disable-static
make
make install

mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/libisl*gdb.py /usr/share/gdb/auto-load/usr/lib


# GCC
pre gcc

sed -e '/m64=/s/lib64/lib/' \
    -i.orig gcc/config/i386/t-linux64

mkdir -v build
cd       build

../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --enable-default-pie     \
             --enable-default-ssp     \
             --enable-host-pie        \
             --disable-nls            \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-fixincludes    \
             --with-system-zlib
make
make install

# LTO compatibility symlink
ln -sfv ../../libexec/gcc/"$(gcc -dumpmachine)"/15.1.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/

# Sanity checks
echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'

grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log
grep -B4 '^ /usr/include' dummy.log
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " dummy.log
grep found dummy.log

# Move a misplaced file
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib


# Gettext
pre gettext
./configure --prefix=/usr       \
            --disable-static    \
            --disable-nls       \
            --disable-rpath     \
            --disable-acl       \
            --without-git       \
            --without-emacs     \
            --without-bzip2     \
            --without-selinux   \
            --with-xz
make
make install
chmod -v 755 /usr/lib/preloadable_libintl.so


# Which
pre which
./configure --prefix=/usr --enable-optimize
make
make install


# Libtool
pre libtool
./configure --prefix=/usr --disable-static
make
make install


# Autoconf
pre autoconf

./configure --prefix=/usr
make
make install


# Automake
pre automake

./configure --prefix=/usr
make
make install


# Cleanup
post
echo "Completed stage 3" >&2
echo "Cleaning up..."    >&2
sleep 2
cd /

# Remove temporary files
rm -rf {,/var}/tmp/*

# Remove lfstage artifacts
rm -rf /{tools,sources}
rm -vf /as_chroot.sh
rm -vf /build.env

# Remove documentation
rm -rf /usr/share/{man,info,doc}/*

# remove unused binaries and scripts
# TODO: Look into:
# - stty
# - sum
# - sha224sum, sha384sum
# - shred
# - setarch, x86_64
# - script*
# - ptar*
# - pr
# - pldd
# - csplit
_del=(
    base32
    bits # TODO: Figure out what even provides this lol
    chcon # selinux
    chmem
    choom
    chrt # this isn't a realtime system
    cksum
    clear
    corelist
    coresched
    cpan
    hexdump
    df
    dmesg # it isn't useful in a stage 2
    gawkbug
    gzexe
    instmodsh
    libnetcfg
    logname # similar to whoami, kinda useless
    look
    lsclocks
    lsfd
    lsipc
    lsirq
    lslogins
    lslocks
    lsns
    lto-dump # huge (42M) binary that I probably dont need
    namei
    nice
    nsenter
    pathchk
    perl{bug,thanks}
    piconv
    pipesz
    pydoc{,3}*
    renice # not needed in a stage 2
    runcon # selinux
    tzselect
    vdir
    wdctl
    xzcat
    xzcmp
    xzdiff
    xz*grep
    xzless
    sotruss
    zipdetails
    zcmp
    zdiff
    zdump
    z*grep
    zforce
    zless
    znew
)

# Remove unnecessary binaries
pushd /usr/bin
    rm -vf "${_del[@]}"
    unset _del
popd

# use symlinks for gawk instead of a duplicate binary
rm -vf /usr/bin/gawk
ln -sv gawk-5.3.2 /usr/bin/gawk

# remove idle
rm -vf /usr/bin/idle3*
rm -rf /usr/lib/python3.*/idlelib

# remove libtool archives
find /usr/{lib,libexec} -name '*.la' -exec rm -vf {} \;

# remove stray readmes
find /{usr,var,opt,etc} -type f -name 'README*' -exec rm -vf {} \;

# remove batch scripts
find /{usr,var,opt,etc} -type f -name '*.bat' -exec rm -vf {} \;

# remove uncommon character encodings
# (utf8 is built into glibc)
find /usr/lib/gconv -type f  \
    ! -name 'ISO8859-1.so'   \
    ! -name 'UTF-16.so'      \
    ! -name 'UTF-32.so'      \
    ! -name 'gconv-modules*' \
    -exec rm -vf {} +

# remove unused locales
find /usr/{share,lib}/locale    \
    -type d                     \
    ! -name 'en_US*'            \
    ! -name 'C.utf8'            \
    -exec rm -rvf {} +

# remove unused terminfo files
find /usr/share/terminfo            \
    -type f                         \
    ! -path '*/l/linux'             \
    ! -path '*/t/tmux'              \
    ! -name '*/x/xterm-256color'    \
    -exec rm -vf {} +
find /usr/share/terminfo -type d -empty -delete

# mark success
touch /good
echo "Finished cleanup" >&2
