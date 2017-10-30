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
ROOTFS=$PWD/platforms/$1/rootfs
OUTPUT_PKGS=$PWD/platforms/$1/pkgs

echo "Building lilala linux for"
echo "Target :$SLK_TARGET"
echo "Toolchain path: $SLK_TOOLCHAIN_PATH"
echo "Final rootfs: $ROOTFS"
echo "Final pkgs output: $OUTPUT_PKGS"
read

export PATH=$PWD/tools/:$SLK_TOOLCHAIN_PATH:$PATH
export PKG_CONFIG_PATH= 
export PKG_CONFIG_LIBDIR=$ROOTFS/usr/lib/pkgconfig:$ROOTFS/usr/lib64/pkgconfig

mkdir -p $ROOTFS

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
n/dropbear \
n/iptables \
n/wpa_supplicant \
n/iw \
n/hostapd \
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
        SLK_TARGET=$SLK_TARGET SLK_SYSROOT=$ROOTFS \
        TAG=$TAG PKGTYPE=$PKGTYPE OUTPUT=$PKG_DIR ./$PKG_NAME.SlackBuild #&> $PKG_DIR/$PKG_NAME.log

        if [ $? -ne 0 ]; then
	    echo "Error in $PKG_NAME.SlackBuild"
	    exit 1
        fi
        if [ -e $PKGFINAL ]; then
            echo "Installing $PKGFINAL"
	    ROOT=$ROOTFS upgradepkg --reinstall --install-new $PKGFINAL    	    
        fi
    else 
	echo "Skipping $i"
    fi
    cd $MAIN_DIR
done

