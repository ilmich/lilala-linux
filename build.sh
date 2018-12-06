#!/bin/sh

function deletepkg() {
    PKG_DIR=$OUTPUT_PKGS/`dirname $1`
    PKG_NAME=`basename $1`
    PKGTYPE=tgz
    TAG=lilala
    SLK_ARCH=`echo $SLK_TARGET | cut -d - -f 1 -`

    if [ -e platforms/$PLATFORM_NAME/src/$1 ]; then
        cd platforms/$PLATFORM_NAME/src/$1
    else
        cd src/$1
    fi

    . ./$PKG_NAME.info
    PKGFINAL=$PKG_DIR/$PKG_NAME-$VERSION-$SLK_ARCH-$BUILD$TAG.$PKGTYPE

    if [ -e $PKGFINAL ]; then
	rm $PKGFINAL
	echo "deleted pkg $PKGFINAL"
    fi

    cd $MAIN_DIR
}

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
        SLK_TARGET=$SLK_TARGET SLK_CFLAGS=$SLK_CFLAGS SLK_SYSROOT=$STAGINGFS \
        TAG=$TAG PKGTYPE=$PKGTYPE OUTPUT=$PKG_DIR STAGING=$STAGINGFS ./$PKG_NAME.SlackBuild # &> $PKG_LOGS/$PKG_NAME.log

        if [ $? -ne 0 ]; then
            echo "Error in $PKG_NAME.SlackBuild"
            exit 1
        fi
        #if [ -e $PKGFINAL ]; then
        #    echo "Installing $i"
        #    ROOT=$ROOTFS upgradepkg --reinstall --install-new $PKGFINAL #&> $PKG_LOGS/$PKG_NAME.install.log
        #fi
    else
        echo "Skipping $1"
    fi
    cd $MAIN_DIR

}

function buildrootfs() {
    for i in `find $OUTPUT_PKGS -name *.t?z`; do
	ROOT=$ROOTFS upgradepkg --reinstall --install-new $i
    done
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

PLATFORM_DIR=$PWD/platforms/$PLATFORM_NAME
OUTPUT_DIR=$MAIN_DIR/output/platforms/$PLATFORM_NAME
ROOTFS=$OUTPUT_DIR/rootfs
STAGINGFS=$OUTPUT_DIR/staging
KERNEL_DIR=$PLATFORM_DIR/kernel
OUTPUT_PKGS=$OUTPUT_DIR/pkgs
OUTPUT_LOGS=$OUTPUT_DIR/logs

mkdir -p $ROOTFS
mkdir -p $STAGINGFS

export PATH=$PWD/tools/:$SLK_TOOLCHAIN_PATH:$PATH
export PKG_CONFIG_PATH= 
export PKG_CONFIG_LIBDIR=$STAGINGFS/usr/lib/pkgconfig:$STAGINGFS/usr/lib64/pkgconfig

BUILDPKG=
DELETEPKG=
case $1 in
    build)
	echo "starting build"
	BUILDPKG="YES"
	shift
	;;
    rebuild)
	DELETEPKG="YES"
	BUILDPKG="YES"
	shift
	;;
    delete)
	DELETEPKG="YES"
	shift
	;;
    cleanfs)
	echo "cleaning target fs"
	rm -r $ROOTFS
	exit 0
	;;
    buildfs)
	echo "build target fs"
	buildrootfs
	exit 0
	;;
    rebuildfs)
	echo "rebuild target fs"
	rm -r $ROOTFS
	mkdir -p $ROOTFS
	buildrootfs
	exit 0
	;;
    *) 
	echo "Command $1 not recognized"
	exit 1
	;;
esac

echo "Building Lilala linux for $PLATFORM_NAME"
echo "----------------------------------------"
echo "Target :$SLK_TARGET"
echo "Toolchain path: $SLK_TOOLCHAIN_PATH"
echo "Compiler flags: $SLK_CFLAGS"
echo "Final rootfs: $ROOTFS"
echo "Staging rootfs: $STAGINGFS"
echo "Final pkgs output: $OUTPUT_PKGS"
echo "----------------------------------------"
echo "Check and press enter to start"
read



while [ $# -gt 0 ] ; do
    # scan for set of packages
    COUNT=`find src/ -name $1.buildlist -printf '.' | wc -c `    
    if [ $(($COUNT)) -eq 1 ]; then
        BUILDLIST=`find src/ -name $1.buildlist`
	for i in `cat $BUILDLIST`; do
	    if [ ! -z $DELETEPKG ]; then
		deletepkg $i
	    fi
	    if [ ! -z $BUILDPKG ]; then
		buildpkg $i
	    fi
	done
    else 
	if [ ! -z $1 ]; then
    	    COUNT=`find src/ -name $1.SlackBuild -printf '.' | wc -c `
	    if [ $(($COUNT)) -eq 1 ]; then
		PKGBUILD=`find src/ -name $1.SlackBuild`
		PKGBUILD=`dirname $PKGBUILD`
		if [ ! -z $DELETEPKG ]; then
		    deletepkg ${PKGBUILD#src/}
		fi
    		if [ ! -z $BUILDPKG ]; then
		    buildpkg ${PKGBUILD#src/}
    		fi
    	    else
		echo "Package $1 not fount"
		exit 1
	    fi
	fi
    fi
    shift
done
