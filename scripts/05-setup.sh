#!/bin/bash

# TODO: Remove this debug line
msg "MAKEFLAGS: $MAKEFLAGS"

# Create a limited directory layout
mkdir -pv "$LFS"/{etc,var,tools} "$LFS"/usr/{bin,lib,sbin}

for i in bin lib sbin; do
    ln -sv "usr/$i" "$LFS/$i"
done

mkdir -pv "$LFS/lib64"
