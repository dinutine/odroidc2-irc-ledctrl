#!/bin/sh

git clone https://github.com/buildroot/buildroot.git
cd buildroot
git checkout 2016.05


cp ../odroidc2_defconfig configs
cp -r ../skeleton board/hardkernel/odroidc2
cp -r ../patches board/hardkernel/odroidc2

make odroidc2_defconfig
make



