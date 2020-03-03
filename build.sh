#!/bin/sh

function findbuildscript() {
	COUNT=`ls -1 platforms/$PLATFORM_NAME/src/*/*/*.SlackBuild 2> /dev/null | grep $1.SlackBuild | wc -l`
	if [ $(($COUNT)) -eq 1 ]; then
		PKGBUILD=`ls -1 platforms/$PLATFORM_NAME/src/*/*/*.SlackBuild | grep $1.SlackBuild`
		PKGBUILD=`dirname $PKGBUILD`
		echo ${PKGBUILD#platforms/$PLATFORM_NAME/src/} >> $2
	else
		COUNT=`ls -1 src/*/*/*.SlackBuild | grep $1.SlackBuild | wc -l`
		if [ $(($COUNT)) -eq 1 ]; then
			PKGBUILD=`ls -1 src/*/*/*.SlackBuild | grep $1.SlackBuild`
			PKGBUILD=`dirname $PKGBUILD`
			echo ${PKGBUILD#src/} >> $2
		else
			return 1
		fi
	fi
	return 0
}

function findbuildlist() {
	# scan platforms buildlist
	COUNT=`ls -1 platforms/$PLATFORM_NAME/*.buildlist 2> /dev/null | grep $1.buildlist | wc -l `
	if [ $(($COUNT)) -eq 1 ]; then
		BUILDLIST=`ls -1 platforms/$PLATFORM_NAME/*.buildlist | grep $1.buildlist`
	else
		# scan source tree buildlist
		COUNT=`ls -1 src/*.buildlist | grep $1.buildlist | wc -l `
		if [ $(($COUNT)) -eq 1 ]; then
			BUILDLIST=`ls -1 src/*.buildlist | grep $1.buildlist`
		else
		    # scan source tree buildlist
		    COUNT=`ls -1 src/*/*.buildlist | grep $1.buildlist | wc -l `
		    if [ $(($COUNT)) -eq 1 ]; then
			BUILDLIST=`ls -1 src/*/*.buildlist | grep $1.buildlist`
		    else
			return 1
		    fi
		fi		
	fi
	
	#parsing buildlist line by line
	while read CMD; do
	#skip comments in buildlist
	if [[ $CMD == \#* ]]; then
		continue;
	fi
	#include another buildlist
	if [[ $CMD == \+* ]]; then
		SUBSTRING=$(echo $CMD | cut -c 2-)
		findbuildlist $SUBSTRING $2
		continue;
	fi
	echo $CMD >> $2
	done < $BUILDLIST

	return 0
}

# TOOD better package removal based on some sort of metadata 
function deletepkg() {
    PKG_DIR=$OUTPUT_PKGS/`dirname $1`
    STAGING_PKG_DIR=$OUTPUT_STAGING_PKGS/`dirname $1`
    PKG_NAME=`basename $1`
    PKGTYPE=tgz
    TAG=lilala
    if [ -z $SLK_ARCH ]; then
        SLK_ARCH=`echo $SLK_TARGET | cut -d - -f 1 -`
    fi
    #check if there is a slackbuild
    if [ -e platforms/$PLATFORM_NAME/src/$1/*.SlackBuild ]; then
        cd platforms/$PLATFORM_NAME/src/$1
    else
        cd src/$1
    fi

    . ./$PKG_NAME.info
    PKGFINAL=$PKG_DIR/$PKG_NAME-*$TAG.*
    PKGSTAGING=$STAGING_PKG_DIR/$PKG_NAME-*$TAG.*

    ROOT=$STAGINGFS removepkg $PKGSTAGING
    rm $PKGFINAL
    rm $PKGSTAGING
    echo "deleted pkg $PKGFINAL"

    cd $MAIN_DIR
}

function buildpkg() {
    PKG_DIR=$OUTPUT_PKGS/`dirname $1`
    STAGING_PKG_DIR=$OUTPUT_STAGING_PKGS/`dirname $1`
    PKG_LOGS=$OUTPUT_LOGS/`dirname $1`
    PKG_NAME=`basename $1`
    PKGTYPE=tgz
    TAG=lilala

    if [ -d $TMP/$1 ]; then
        rm -r $TMP/$1
    fi
    mkdir -p $TMP/$1
    cp -r -a  src/$1/* $TMP/$1 2>/dev/null

    # overlay platform source
    if [ -d platforms/$PLATFORM_NAME/src/$1 ]; then
        cp -r -a platforms/$PLATFORM_NAME/src/$1/* $TMP/$1
    fi

    cd $TMP/$1
    . ./$PKG_NAME.info

    # download source code
    if [ ! -z $DOWNLOAD_URL ]; then
        SOURCE_TAR=${SOURCE_TAR:-`basename $DOWNLOAD_URL`}

        if [ ! -e ${CACHE_DIR}/$SOURCE_TAR ]; then
            wget -c $DOWNLOAD_URL -O $CACHE_DIR/$SOURCE_TAR
        fi

        # linking source tar
        ln -s $CACHE_DIR/$SOURCE_TAR .

        # unset SOURCE_TAR
        SOURCE_TAR=
    fi

    ARCH=`echo $SLK_TARGET | cut -d - -f 1 -`
    if [ -z $SLK_ARCH ]; then
        SLK_ARCH=$ARCH
    fi
    PKGFINAL=$PKG_DIR/$PKG_NAME-$VERSION-$SLK_ARCH-$BUILD$TAG.$PKGTYPE
    PKGFINALDEV=$STAGING_PKG_DIR/$PKG_NAME-$VERSION-$SLK_ARCH-$BUILD$TAG.$PKGTYPE

    if [ ! -e $PKGFINALDEV ]; then
        echo "Building $1"
        mkdir -p $PKG_DIR
        mkdir -p $STAGING_PKG_DIR
        SLK_PLATFORM=$SLK_PLATFORM SLK_TARGET=$SLK_TARGET SLK_CFLAGS=$SLK_CFLAGS SLK_SYSROOT=$STAGINGFS ARCH=$ARCH SLK_ARCH=$SLK_ARCH \
        SLK_TOOLCHAIN_PATH=$SLK_TOOLCHAIN_PATH TAG=$TAG PKGTYPE=$PKGTYPE OUTPUT=$STAGING_PKG_DIR \
        STAGING=$STAGINGFS ./$PKG_NAME.SlackBuild # &> $PKG_LOGS/$PKG_NAME.log

        if [ $? -ne 0 ]; then
            echo "Error in $PKG_NAME.SlackBuild"
            exit 1
        fi
#       if [ -e $PKGFINAL ]; then
#           echo "Installing $i"
#           ROOT=$ROOTFS upgradepkg --reinstall --install-new $PKGFINAL #&> $PKG_LOGS/$PKG_NAME.install.log
#       fi

	if [ -z $SLK_STRIP_PKG ]; then
	    cp $PKGFINALDEV $PKGFINAL
	else
	    # strip pkg
	    echo "stripping pkg"
	    mkdir -p /tmp/strip-$PKG_NAME
	    (
		cd /tmp/strip-$PKG_NAME
		explodepkg $PKGFINALDEV > /dev/null
		rm -rf usr/man \
		       usr/share/man \
		       usr/include \
		       usr/share/locale \
		       usr/share/info \
		       usr/doc \
		       usr/lib64/pkgconfig \
		       usr/lib/pkgconfig \
		       lib/pkgconfig \
		       usr/share/aclocal
		makepkg -l y -c n $PKGFINAL > /dev/null
	    )
	    rm -rf /tmp/strip-$PKG_NAME
	fi

	if [ -e $PKGFINALDEV ]; then
	    echo "Installing on staging $i"
	    ROOT=$STAGINGFS upgradepkg --reinstall --install-new $PKGFINALDEV #&> $PKG_LOGS/$PKG_NAME.install.log
	fi
    else
        echo "Skipping $1"
    fi
    cd $MAIN_DIR

}

function buildrootfs() {
    for i in `find $OUTPUT_PKGS -name *.t?z`; do
	ROOT=$ROOTFS upgradepkg --reinstall --install-new --terse $i
    done
    (
	cd $ROOTFS
        tar cvJf $OUTPUT_DIR/lilala-linux-rootfs.tar.xz .
    )
    echo "Filesystem size:"
    du -d 0 -h $ROOTFS
}

function usage() {
    echo "usage: $0 [build|rebuild|delete|cleanfs|buildfs|rebuildfs]"
    echo ""
    echo "      build [package|buildlist]       build single or multiple package"
    echo "      rebuild [package|buildlist]     rebuild single or multiple package"
    echo "      delete [package|buildlist]      debuild single or multiple package"
    echo "      cleanfs                         clean output filesystem"
    echo "      buildfs                         build output filesystem"
    echo "      rebuildfs                       rebuild output filesystem"
    exit 1
}

function showbuildinfo() {

    echo "Building Lilala linux for $PLATFORM_NAME"
    echo "----------------------------------------"
    echo "Target :$SLK_TARGET"
    echo "Targhet arch: $SLK_ARCH"
    echo "Toolchain path: $SLK_TOOLCHAIN_PATH"
    echo "Compiler flags: $SLK_CFLAGS"
    echo "Final rootfs: $ROOTFS"
    echo "Staging rootfs: $STAGINGFS"
    echo "Final pkgs output: $OUTPUT_PKGS"
    echo "----------------------------------------"
    echo "Check and press enter to start"
    read
    
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
OUTPUT_DIR=$MAIN_DIR/output/target-$PLATFORM_NAME
ROOTFS=$OUTPUT_DIR/rootfs
STAGINGFS=$OUTPUT_DIR/staging
KERNEL_DIR=$PLATFORM_DIR/kernel
OUTPUT_PKGS=$OUTPUT_DIR/pkgs
CACHE_DIR=$MAIN_DIR/cache
OUTPUT_STAGING_PKGS=$OUTPUT_DIR/staging_pkgs
OUTPUT_LOGS=$OUTPUT_DIR/logs
TMP=/tmp/lilala

mkdir -p $ROOTFS
mkdir -p $STAGINGFS
mkdir -p $CACHE_DIR

export PATH=$PWD/tools/:$SLK_TOOLCHAIN_PATH/bin:$PATH
export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR=$STAGINGFS/usr/lib/pkgconfig:$STAGINGFS/usr/lib64/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=$STAGINGFS

BUILDPKG=
DELETEPKG=
case $1 in
    build)
	echo "starting build"
    showbuildinfo
	BUILDPKG="YES"
	shift
	;;
    rebuild)
    showbuildinfo
	DELETEPKG="YES"
	BUILDPKG="YES"
	shift
	;;
    delete)
    showbuildinfo
	DELETEPKG="YES"
	shift
	;;
    cleanfs)
    showbuildinfo
	echo "cleaning target fs"
	rm -r $ROOTFS
	exit 0
	;;
    buildfs)
    showbuildinfo
	echo "build target fs"
	buildrootfs
	exit 0
	;;
    rebuildfs)
    showbuildinfo
	echo "rebuild target fs"
	rm -r $ROOTFS
	mkdir -p $ROOTFS
	buildrootfs
	exit 0
	;;
    *) 
	echo "Command $1 not recognized"
	usage
	exit 1
	;;
esac

rm -f $OUTPUT_DIR/buildlist
while [ $# -gt 0 ] ; do
    findbuildlist $1 $OUTPUT_DIR/buildlist
    if [ "$?" == 1 ]; then
	findbuildscript $1 $OUTPUT_DIR/buildlist
	if [ $? -eq 1 ]; then
		echo "package or buildlist $1 not exists"
		exit 1
	fi
    fi

    shift
done

for i in `cat $OUTPUT_DIR/buildlist`; do
	if [ ! -z $DELETEPKG ]; then
		deletepkg $i
	fi
	if [ ! -z $BUILDPKG ]; then
		buildpkg $i
	fi
done
