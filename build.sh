#!/bin/sh

MAIN_DIR=$PWD

if [ ! -e $MAIN_DIR/output/platform ]; then
    echo "Platform file not exists. Please run build_setup.sh first!!"
    exit 1
fi

PLATFORM_NAME=`cat $MAIN_DIR/output/platform`

if [ ! -e $MAIN_DIR/platforms/$PLATFORM_NAME/platform_env.sh ]; then
    echo "File platform_env.sh not found!! This is wrong!!!"
    exit 1
fi

. $MAIN_DIR/platforms/$PLATFORM_NAME/platform_env.sh

if [ -z "$PLATFORM_NAME" ]; then
    echo "Unknown platform name. Please check platform setup"
    exit 1
fi

PLATFORM_DIR=$PWD/platforms/$PLATFORM_NAME
OUTPUT_DIR=$MAIN_DIR/output/platforms/$PLATFORM_NAME
ROOTFS=$OUTPUT_DIR/rootfs
STAGINGFS=$OUTPUT_DIR/staging
KERNEL_DIR=$PLATFORM_DIR/kernel
OUTPUT_PKGS=$OUTPUT_DIR/pkgs
OUTPUT_LOGS=$OUTPUT_DIR/logs

echo "Building Lilala linux for $PLATFORM_NAME"
echo "----------------------------------------"
echo "Target :$SLK_TARGET"
echo "Toolchain path: $SLK_TOOLCHAIN_PATH"
echo "Final rootfs: $ROOTFS"
echo "Staging rootfs: $STAGINGFS"
echo "Final pkgs output: $OUTPUT_PKGS"
echo "----------------------------------------"
echo "Check and press enter to start build"
read

export PATH=$PWD/tools/:$SLK_TOOLCHAIN_PATH:$PATH
export PKG_CONFIG_PATH= 
export PKG_CONFIG_LIBDIR=$STAGINGFS/usr/lib/pkgconfig:$STAGINGFS/usr/lib64/pkgconfig

mkdir -p $ROOTFS
mkdir -p $STAGINGFS

for i in \
core/aaa_base \
core/etc \
core/tzdb \
core/keymaps \
core/musl \
core/zlib \
core/sinit \
core/ubase \
core/sbase \
core/mksh \
core/kmod \
core/libmnl \
core/libnftnl \
core/libpcap \
core/openssl \
core/e2fsprogs \
core/openssh \
core/iptables
do

    PKG_DIR=$OUTPUT_PKGS/`dirname $i`
    PKG_LOGS=$OUTPUT_LOGS/`dirname $i`
    PKG_NAME=`basename $i`
    PKGTYPE=tgz
    TAG=lilala
    if [ -e platforms/$PLATFORM_NAME/src/$i ]; then
        cd platforms/$PLATFORM_NAME/src/$i
    else
        cd src/$i
    fi
    . ./$PKG_NAME.info
    SLK_ARCH=`echo $SLK_TARGET | cut -d - -f 1 -`
    PKGFINAL=$PKG_DIR/$PKG_NAME-$VERSION-$SLK_ARCH-$BUILD$TAG.$PKGTYPE
    if [ ! -e $PKGFINAL ]; then
        echo "Building $i"
        mkdir -p $PKG_DIR
	mkdir -p $PKG_LOGS
        SLK_TARGET=$SLK_TARGET SLK_SYSROOT=$STAGINGFS \
        TAG=$TAG PKGTYPE=$PKGTYPE OUTPUT=$PKG_DIR STAGING=$STAGINGFS ./$PKG_NAME.SlackBuild # &> $PKG_LOGS/$PKG_NAME.log

        if [ $? -ne 0 ]; then
            echo "Error in $PKG_NAME.SlackBuild"
            exit 1
        fi
        if [ -e $PKGFINAL ]; then
            echo "Installing $i"
            ROOT=$ROOTFS upgradepkg --reinstall --install-new $PKGFINAL #&> $PKG_LOGS/$PKG_NAME.install.log
        fi
    else
        echo "Skipping $i"
    fi
    cd $MAIN_DIR
done
