#!/bin/sh

function buildpkg() {

    PKG_DIR=$OUTPUT_PKGS/`dirname $1`
    PKG_LOGS=$OUTPUT_LOGS/`dirname $1`
    PKG_NAME=`basename $1`
    PKGTYPE=tgz
    TAG=lilala
    if [ -e platforms/$PLATFORM_NAME/src/$1 ]; then
        cd platforms/$PLATFORM_NAME/src/$1
    else
        cd src/$1
    fi
    . ./$PKG_NAME.info
    SLK_ARCH=`echo $SLK_TARGET | cut -d - -f 1 -`
    PKGFINAL=$PKG_DIR/$PKG_NAME-$VERSION-$SLK_ARCH-$BUILD$TAG.$PKGTYPE
    if [ ! -e $PKGFINAL ]; then
        echo "Building $1"
        mkdir -p $PKG_DIR
#	mkdir -p $PKG_LOGS
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
        echo "Skipping $1"
    fi
    cd $MAIN_DIR

}

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

case $1 in
    build)
	echo "starting build"
	shift
	;;
    *) 
	echo "Command $1 not recognized"
	exit 1
	;;
esac

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

while [ $# -gt 0 ] ; do
    # scan for set of packages
    BUILDLIST=`find src/ -name $1.buildlist`
    COUNT=`echo $BUILDLIST | wc -l `
    if [ $(($COUNT)) -eq 1 ]; then
	for i in `cat $BUILDLIST`; do
	    buildpkg $1/$i
	done
    fi
    shift
done
