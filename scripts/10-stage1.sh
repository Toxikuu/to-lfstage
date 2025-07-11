#!/bin/bash
set -euo pipefail # paranoia
# Build a stage1 toolchain

# shellcheck disable=2086,2164,1091,2046

source "$ENVS/build.env"
cd     "$LFS/sources"


# Binutils - Pass 1
pre binutils

mkdir -v build
cd       build

../configure --prefix="$LFS/tools" \
             --with-sysroot="$LFS" \
             --target="$LFS_TGT"   \
             --disable-nls         \
             --enable-gprofng=no   \
             --disable-werror      \
             --enable-new-dtags    \
             --enable-default-hash-style=gnu
make
make install


# GCC - Pass 1
pre gcc

tar -xf ../mpfr-[0-9]*.tar.xz
mv -v mpfr-[0-9]* mpfr
tar -xf ../gmp-[0-9]*.tar.xz
mv -v gmp-[0-9]* gmp
tar -xf ../mpc-[0-9]*.tar.gz
mv -v mpc-[0-9]* mpc

sed -e '/m64=/s/lib64/lib/' \
    -i.orig gcc/config/i386/t-linux64

mkdir -v build
cd       build

../configure                  \
    --target="$LFS_TGT"       \
    --prefix="$LFS/tools"     \
    --with-glibc-version=2.41 \
    --with-sysroot="$LFS"     \
    --with-newlib             \
    --without-headers         \
    --enable-default-pie      \
    --enable-default-ssp      \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++
make
make install

cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h


# Linux API Headers
pre linux

make mrproper

make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include "$LFS/usr"


# Glibc
pre glibc

# Create symlinks for LSB compliance
ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64"
ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3"

# FHS compliance
patch -Np1 -i ../glibc-2.41-fhs-1.patch

mkdir -v build
cd       build

# shellcheck disable=2155
export BLD="$(../scripts/config.guess)"

echo "rootsbindir=/usr/sbin" > configparms
../configure                    \
      --prefix=/usr             \
      --host="$LFS_TGT"         \
      --build="$BLD"            \
      --disable-nscd            \
      libc_cv_slibdir=/usr/lib  \
      --enable-kernel=6.12
make
make DESTDIR="${LFS:?}" install # paranoia

# Fix a hardcoded path in the ldd script
sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"

# Perform some sanity checks
echo 'int main(){}' | "$LFS_TGT-gcc" -x c - -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'

grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" dummy.log
grep -B3 "^ $LFS/usr/include" dummy.log
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " dummy.log
grep found dummy.log
rm -v a.out dummy.log


# Libstdc++ from GCC
pre gcc

mkdir -v build
cd       build

../libstdc++-v3/configure   \
    --host="$LFS_TGT"       \
    --build="$BLD"          \
    --prefix=/usr           \
    --disable-multilib      \
    --disable-nls           \
    --disable-libstdcxx-pch \
    --with-gxx-include-dir="/tools/$LFS_TGT/include/c++/15.1.0"
make
make DESTDIR="$LFS" install
rm -vf "$LFS"/usr/lib/lib{stdc++{,exp,fs},supc++}.la

post
msg "Finished building stage 1"
