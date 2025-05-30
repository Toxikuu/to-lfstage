#!/bin/bash
set -euo pipefail # paranoia
# Build a stage 2 toolchain

# shellcheck disable=2086,2164,1091,2046

source "$ENVS/build.env"
cd     "$LFS/sources"


# M4
pre m4

sed 's/\[\[__nodiscard__]]//' -i lib/config.hin

# shellcheck disable=2155
export BLD="$(build-aux/config.guess)"

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$BLD"      \
            --disable-nls       \
            --disable-rpath     \
            --disable-assert
make
make DESTDIR="$LFS" install


# Ncurses
# NOTE: A specific ncurses snapshot is used (ncurses-6.5-20250517) to avoid
# gcc >= 15 errors
pre ncurses

mkdir -v build
pushd build
    ../configure AWK=gawk
    make -C include
    make -C progs tic
popd

./configure --prefix=/usr                \
            --host="$LFS_TGT"            \
            --build="$BLD"               \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-{cxx,}shared          \
            --without-normal             \
            --without-tests              \
            --without-debug              \
            --without-profile            \
            --without-ada                \
            --disable-stripping          \
            --disable-home-terminfo      \
            AWK=gawk
make
make DESTDIR="$LFS" TIC_PATH="$(pwd)/build/progs/tic" install
ln -sv libncursesw.so "$LFS/usr/lib/libncurses.so"
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i "$LFS/usr/include/curses.h"


# Bash
pre bash

# NOTE: The rc1 version is used because it plays nicer with GCC >= 15
# Fix a build issue occuring when the host has GCC >= 15
patch -Np1 <<EOF
--- bash-5.3-rc1/bashansi.h     2024-03-26 00:17:49.000000000 +0800
+++ bash-5.3-rc1.patched/bashansi.h     2025-05-21 15:04:17.090096535 +0800
@@ -35,8 +35,11 @@
 #  include "ansi_stdlib.h"
 #endif /* !HAVE_STDLIB_H */
 
-/* If bool is not a compiler builtin, prefer stdbool.h if we have it */
-#if !defined (HAVE_C_BOOL)
+/* If bool is not a compiler builtin, prefer stdbool.h if we have it
+
+   Explicitly check __STDC_VERSION__ here in addition to HAVE_C_BOOL:
+   in cross-compilation build tools does not include config.h.  */
+#if !defined (HAVE_C_BOOL) && (!defined(__STDC_VERSION__) || __STDC_VERSION__ < 202311L)
 #  if defined (HAVE_STDBOOL_H)
 #    include <stdbool.h>
 #  else
EOF

./configure --prefix=/usr           \
            --build="$BLD"          \
            --host="$LFS_TGT"       \
            --without-bash-malloc   \
            --disable-bang-history  \
            --disable-nls           \
            --disable-rpath
make
make DESTDIR="$LFS" install
ln -sv bash "$LFS/bin/sh"


# Coreutils
pre coreutils

# NOTE: The `hostname` program is wanted by more than just the Perl test suite.
# Many configure scripts call it.
./configure --prefix=/usr                       \
            --host="$LFS_TGT"                   \
            --build="$BLD"                      \
            --disable-assert                    \
            --disable-rpath                     \
            --disable-nls                       \
            --disable-systemd                   \
            --enable-single-binary=symlinks     \
            --enable-install-program=hostname   \
            --enable-no-install-program=kill,uptime
make
make DESTDIR="$LFS" install

mv -vf      "$LFS/usr/bin/chroot"               "$LFS/usr/sbin"
mkdir -pv   "$LFS/usr/share/man/man8"
mv -vf      "$LFS/usr/share/man/man1/chroot.1"  "$LFS/usr/share/man/man8/chroot.8"
sed -i      's/"1"/"8"/'                        "$LFS/usr/share/man/man8/chroot.8"


# Diffutils
pre diffutils

./configure --prefix=/usr                   \
            --host="$LFS_TGT"               \
            --build="$BLD"                  \
            --disable-rpath                 \
            --disable-nls                   \
            gl_cv_func_strcasecmp_works=y
make
make DESTDIR="$LFS" install


# File
pre file

_cfg=(
    --disable-libseccomp
    --disable-zlib
    --disable-bzlib
    --disable-xzlib
    --disable-lzlib
    --disable-zstdlib
    --disable-lrziplib
    --disable-shared
    --disable-static
)

mkdir -v build
pushd build
    ../configure "${_cfg[@]}"
    make
popd

./configure "${_cfg[@]}"    \
    --prefix=/usr           \
    --host="$LFS_TGT"       \
    --build="$BLD"          \
    --enable-shared         \
    --datadir=/usr/share/file

unset _cfg

make FILE_COMPILE="$(pwd)/build/src/file"
make DESTDIR="$LFS" install
rm -vf "$LFS/usr/lib/libmagic.la"


# Findutils
pre findutils

./configure --prefix=/usr                   \
            --localstatedir=/var/lib/locate \
            --host="$LFS_TGT"               \
            --build="$BLD"                  \
            --disable-assert                \
            --disable-nls                   \
            --disable-rpath
make
make DESTDIR="$LFS" install


# Gawk
pre gawk

# Don't install unneeded extra files
sed -i 's/extras//' Makefile.in

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$BLD"      \
            --disable-nls       \
            --disable-rpath
make
make DESTDIR="$LFS" install


# Grep
pre grep

./configure --prefix=/usr       \
            --build="$BLD"      \
            --host="$LFS_TGT"   \
            --disable-nls       \
            --disable-rpath     \
            --disable-assert
make
make DESTDIR="$LFS" install


# Gzip
pre gzip

./configure --prefix=/usr --host="$LFS_TGT"
make
make DESTDIR="$LFS" install


# Make
pre make

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$BLD"      \
            --disable-nls       \
            --disable-rpath
make
make DESTDIR="$LFS" install


# Patch
pre patch

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$BLD"      \
            --disable-xattr
make
make DESTDIR="$LFS" install


# Sed
pre sed

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$BLD"      \
            --disable-acl       \
            --disable-i18n      \
            --disable-assert    \
            --disable-nls       \
            --disable-rpath
make
make DESTDIR="$LFS" install


# Tar
pre tar

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$BLD"      \
            --disable-acl       \
            --disable-nls       \
            --disable-rpath     \
            --without-xattrs
make
make DESTDIR="$LFS" install


# Xz
pre xz

./configure --prefix=/usr           \
            --host="$LFS_TGT"       \
            --build="$BLD"          \
            --disable-microlzma     \
            --disable-lzip-decoder  \
            --enable-small          \
            --enable-threads=posix  \
            --disable-lzmadec       \
            --disable-lzmainfo      \
            --disable-lzma-links    \
            --disable-scripts       \
            --disable-doc           \
            --disable-nls           \
            --disable-rpath         \
            --disable-static
make
make DESTDIR="$LFS" install
rm -vf "$LFS/usr/lib/liblzma.la"


# Binutils - Pass 2
pre binutils

sed '6031s/$add_dir//' -i ltmain.sh

mkdir -v build
cd       build

../configure            \
    --prefix=/usr       \
    --build="$BLD"      \
    --host="$LFS_TGT"   \
    --disable-nls       \
    --enable-shared     \
    --disable-gprofng   \
    --disable-werror    \
    --enable-64-bit-bfd \
    --enable-new-dtags  \
    --enable-default-hash-style=gnu
make
make DESTDIR="$LFS" install

rm -v "$LFS"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}


# GCC - Pass 2
# NOTE: This breaks the cross toolchain, but this doesn't matter since we chroot
# immediately after.
pre gcc

tar -xf ../mpfr-4.2.2.tar.xz
mv -v mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz
mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz
mv -v mpc-1.3.1 mpc

sed -e '/m64=/s/lib64/lib/' \
    -i.orig gcc/config/i386/t-linux64

sed '/thread_header =/s/@.*@/gthr-posix.h/' \
    -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

mkdir -v build
cd       build

../configure                    \
    --build="$BLD"              \
    --host="$LFS_TGT"           \
    --target="$LFS_TGT"         \
    --prefix=/usr               \
    --with-build-sysroot="$LFS" \
    --enable-default-pie        \
    --enable-default-ssp        \
    --disable-nls               \
    --disable-multilib          \
    --disable-libatomic         \
    --disable-libgomp           \
    --disable-libquadmath       \
    --disable-libsanitizer      \
    --disable-libssp            \
    --disable-libvtv            \
    --enable-languages=c,c++    \
    LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc"
make
make DESTDIR="$LFS" install

# Install compatibility stuff
ln -sfv gcc "$LFS/usr/bin/cc"
install -vm755 /dev/stdin "$LFS/usr/bin/c99" << 'EOF'
#!/bin/sh
exec gcc -std=c99 -pedantic "$@"
EOF

post
msg "Finished building stage 2"
