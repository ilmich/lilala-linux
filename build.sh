#!/bin/sh

MAIN_DIR=$PWD

if [ "$1" == "" ]; then
    echo "Usage $0 platform_name"
    exit 1
fi

if [ ! -e $PWD/platforms/$1/platform_env.sh ]; then
    echo "Platform $1 not exists"
    exit 1
fi

. $PWD/platforms/$1/platform_env.sh
PLATFORM_DIR=$PWD/platforms/$1
OUTPUT_DIR=$MAIN_DIR/output/platforms/$1
ROOTFS=$OUTPUT_DIR/rootfs
STAGINGFS=$OUTPUT_DIR/staging
KERNEL_DIR=$PLATFORM_DIR/kernel
OUTPUT_PKGS=$OUTPUT_DIR/pkgs

echo "Building lilala linux for"
echo "Target :$SLK_TARGET"
echo "Toolchain path: $SLK_TOOLCHAIN_PATH"
echo "Final rootfs: $ROOTFS"
echo "Staging rootfs: $STAGINGFS"
echo "Final pkgs output: $OUTPUT_PKGS"
read

export PATH=$PWD/tools/:$SLK_TOOLCHAIN_PATH:$PATH
export PKG_CONFIG_PATH= 
export PKG_CONFIG_LIBDIR=$STAGINGFS/usr/lib/pkgconfig:$STAGINGFS/usr/lib64/pkgconfig

mkdir -p $ROOTFS
mkdir -p $STAGINGFS

for i in \
a/aaa_base \
a/etc \
a/tzdb \
a/keymaps \
l/musl \
l/zlib \
l/libmnl \
l/libnftnl \
l/libpcap \
l/openssl \
l/libnl \
l/ncurses \
a/busybox \
a/e2fsprogs \
a/kmod \
a/dialog \
n/openssh \
n/iptables \
n/wpa_supplicant \
n/iw \
n/hostapd \
n/dnsmasq \
n/wireless-tools;
do
    PKG_DIR=$OUTPUT_PKGS/`dirname $i`
    PKG_NAME=`basename $i`
    PKGTYPE=tgz
    TAG=lilala
    mkdir -p $PKG_DIR
    if [ -e platforms/$1/src/$i ]; then
        cd platforms/$1/src/$i
    else
        cd src/$i
    fi
    . ./$PKG_NAME.info
    SLK_ARCH=`echo $SLK_TARGET | cut -d - -f 1 -`
    PKGFINAL=$PKG_DIR/$PKG_NAME-$VERSION-$SLK_ARCH-$BUILD$TAG.$PKGTYPE
    if [ ! -e $PKGFINAL ]; then
        echo "Building $i"
        SLK_TARGET=$SLK_TARGET SLK_SYSROOT=$STAGINGFS \
        TAG=$TAG PKGTYPE=$PKGTYPE OUTPUT=$PKG_DIR STAGING=$STAGINGFS ./$PKG_NAME.SlackBuild &> $PKG_DIR/$PKG_NAME.log

        if [ $? -ne 0 ]; then
            echo "Error in $PKG_NAME.SlackBuild"
            exit 1
        fi
        if [ -e $PKGFINAL ]; then
            echo "Installing $i"
            ROOT=$ROOTFS upgradepkg --reinstall --install-new $PKGFINAL &> $PKG_DIR/$PKG_NAME.install.log
        fi
    else
        echo "Skipping $i"
    fi
    cd $MAIN_DIR
done
