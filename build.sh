#!/bin/sh

buildimage() {
cat > $TMP/genimage.cfg << EOF
image rootfs.ext4 {
    ext4 {
        use-mke2fs = "true"
    }
    mountpoint = "/"
    size = 500M
}
image boot.vfat {
    vfat {}
    mountpoint = "/boot-$SLK_BOARD"
    size = 64M
}
EOF

cat $PLATFORM_DIR/genimage.cfg >> $TMP/genimage.cfg
rm -rf $TMP/gentmp
genimage --config $TMP/genimage.cfg \
	--rootpath $ROOTFS \
         --tmppath $TMP/gentmp \
         --mke2fs /sbin/mke2fs \
         --mkdosfs /sbin/mkdosfs \
         --e2fsck /sbin/e2fsck  \
         --outputpath $OUTPUT_DIR/images-$SLK_BOARD

if [ -e $PLATFORM_DIR/install-bootloader-$SLK_BOARD.sh ]; then
    source $PLATFORM_DIR/install-bootloader-$SLK_BOARD.sh
    install $OUTPUT_DIR/images-$SLK_BOARD/sdcard.img
fi

#gzip $OUTPUT_DIR/images-$SLK_BOARD/sdcard.img

}

applypatches() {
    if [ -d $1 ]; then
        #apply patches
        for i in `find $1 -name *.patch | sort -`; do
            echo "Apply patch $i"
            patch -p1 < $i
        done
    fi
}

downloadsource() {
    # download source code
    if [ ! -z $3 ]; then
        SOURCE_TAR=$3
    else
        SOURCE_TAR=`basename $1`
    fi

    if [ ! -e ${CACHE_DIR}/$SOURCE_TAR ]; then
        wget -c $1 -O $CACHE_DIR/$SOURCE_TAR
    fi

    if [ ! $2 == `sha1sum $CACHE_DIR/$SOURCE_TAR | cut -d " " -f 1` ]; then
        SUM=`sha1sum $CACHE_DIR/$SOURCE_TAR | cut -d " " -f 1`
        echo "SHA1 did not match, found $SUM expected $2"
        exit 1
    fi
}

findbuildscript() {
    COUNT=`ls -1 platforms/$PLATFORM_NAME/src/*/*/*.build 2> /dev/null | grep \/$1.build | wc -l`
    if [ $(($COUNT)) -eq 1 ]; then
        PKGBUILD=`ls -1 platforms/$PLATFORM_NAME/src/*/*/*.build | grep \/$1.build`
        PKGBUILD=`dirname $PKGBUILD`
        echo ${PKGBUILD#platforms/$PLATFORM_NAME/src/} >> $2
    else
        COUNT=`ls -1 src/*/*/*.build | grep \/$1.build | wc -l`
        if [ $(($COUNT)) -eq 1 ]; then
            PKGBUILD=`ls -1 src/*/*/*.build | grep \/$1.build`
            PKGBUILD=`dirname $PKGBUILD`
            echo ${PKGBUILD#src/} >> $2
            else
            return 1
            fi
    fi
    return 0
}

findbuildlist() {
    # scan platforms buildlist
    COUNT=`ls -1 platforms/$PLATFORM_NAME/*.buildlist 2> /dev/null | grep \/$1.buildlist | wc -l `
    if [ $(($COUNT)) -eq 1 ]; then
        BUILDLIST=`ls -1 platforms/$PLATFORM_NAME/*.buildlist | grep \/$1.buildlist`
    else
        # scan source tree buildlist
        COUNT=`ls -1 src/*.buildlist | grep \/$1.buildlist | wc -l `
        if [ $(($COUNT)) -eq 1 ]; then
            BUILDLIST=`ls -1 src/*.buildlist | grep \/$1.buildlist`
        else
            # scan source tree buildlist
            COUNT=`ls -1 src/*/*.buildlist | grep \/$1.buildlist | wc -l `
            if [ $(($COUNT)) -eq 1 ]; then
                BUILDLIST=`ls -1 src/*/*.buildlist | grep \/$1.buildlist`
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
deletepkg() {
    PKG_DIR=$OUTPUT_PKGS/`dirname $1`
    STAGING_PKG_DIR=$OUTPUT_STAGING_PKGS/`dirname $1`
    PKG_NAME=`basename $1`
    if [ -z $SLK_ARCH ]; then
        SLK_ARCH=`echo $SLK_TARGET | cut -d - -f 1 -`
    fi
    #check if there is a slackbuild
    if [ -e platforms/$PLATFORM_NAME/src/$1/*.build ]; then
        cd platforms/$PLATFORM_NAME/src/$1
    else
        cd src/$1
    fi

    . ./$PKG_NAME.build
    PKGFINAL=$PKG_DIR/$PKG_NAME-*$TAG.*
    PKGSTAGING=$STAGING_PKG_DIR/$PKG_NAME-*$TAG.*

    ROOT=$STAGINGFS removepkg $PKGSTAGING
    rm $PKGFINAL
    rm $PKGSTAGING
    echo "deleted pkg $PKGFINAL"

    cd $MAIN_DIR
}

buildpkg() {
    PKG_DIR=$OUTPUT_PKGS/`dirname $1`
    STAGING_PKG_DIR=$OUTPUT_STAGING_PKGS/`dirname $1`
    PKG_LOGS=$OUTPUT_LOGS/`dirname $1`
    PKG_NAME=`basename $1`

    if [ -d $TMP/$1 ]; then
        rm -r $TMP/$1
    fi
    mkdir -p $TMP/$1
    cp -r -a  src/$1/* $TMP/$1 2>/dev/null

    # overlay platform source
    if [ -d platforms/$PLATFORM_NAME/src/$1 ]; then
        cp -r -a platforms/$PLATFORM_NAME/src/$1/* $TMP/$1
    fi

    DOWNLOAD_URL=
    SOURCE_TAR=
    DOWNLOAD_SHA1=

    cd $TMP/$1
    . ./$PKG_NAME.build
    #load override build
    if [ -e $PKG_NAME.build.override ]; then
        . ./$PKG_NAME.build.override
    fi

    ARCH=`echo $SLK_TARGET | cut -d - -f 1 -`
    if [ -z $SLK_ARCH ]; then
        SLK_ARCH=$ARCH
    fi
    PKGFINAL=$PKG_DIR/$PKG_NAME-$VERSION-$SLK_ARCH-$BUILD$TAG.$PKGTYPE
    PKGFINALDEV=$STAGING_PKG_DIR/$PKG_NAME-$VERSION-$SLK_ARCH-$BUILD$TAG.$PKGTYPE

    if [ ! -e $PKGFINALDEV ]; then
        # remove oldest package
        rm -f $STAGING_PKG_DIR/$PKG_NAME*-$SLK_ARCH*$TAG.$PKGTYPE

        echo "Building $1"
        mkdir -p $PKG_DIR
        mkdir -p $STAGING_PKG_DIR
        (
            # download source code
            if [ ! -z $DOWNLOAD_URL ]; then
                if [ ! -z $DOWNLOAD_SHA1 ]; then
                    downloadsource $DOWNLOAD_URL $DOWNLOAD_SHA1 $SOURCE_TAR
                else
                    downloadsource $DOWNLOAD_URL "" $SOURCE_TAR
                fi
                ln -s $CACHE_DIR/$SOURCE_TAR .
            fi

            # setup some vars
            OUTPUT=$STAGING_PKG_DIR
            PKG=$TMP/`dirname $1`/package-$PRGNAM
            CWD=$(pwd)
            SLK_SYSROOT=$STAGINGFS

            # cleanup tmp files
            rm -rf $PKG
            mkdir -p $TMP $PKG $OUTPUT
            # build package
            set -e
            build

            #ensure return to build script dir
            cd $CWD 
            mkdir -p $PKG/install
            cat slack-desc > $PKG/install/slack-desc
            if [ -e doinst.sh ]; then
                cat doinst.sh > $PKG/install/doinst.sh
            fi
            #generate slack-required
            if [ ! -z "$DEPS" ]; then
                for i in $DEPS;
                do
                        echo $i >> $PKG/install/slack-required
                done
            fi

            #strip binaries and make package
            ( cd $PKG
              find . | xargs file | grep "executable" | grep ELF | cut -f 1 -d : | xargs -r $SLK_TARGET-strip --strip-unneeded 2> /dev/null || true
              find . | xargs file | grep "shared object" | grep ELF | cut -f 1 -d : | xargs -r $SLK_TARGET-strip --strip-unneeded 2> /dev/null || true
              find . | xargs file | grep "current ar archive" | cut -f 1 -d : | xargs -r $SLK_TARGET-strip --strip-unneeded 2> /dev/null || true              
              mkdir -p $OUTPUT
              rm -f usr/lib/*.a
              rm -f lib/*.a
              rm -f lib/*.la
              rm -f usr/lib/*.la
              makepkg -l n -c n $PKGFINALDEV

              rm -f $PKG_DIR/$PKG_NAME*-$SLK_ARCH*$TAG.$PKGTYPE

              if [ ! -z $SLK_STRIP_PKG ]; then
                rm -rf usr/man \
                        usr/share/man \
                        usr/include \
                        usr/share/locale \
                        usr/share/info \
                        usr/doc \
                        usr/lib64/pkgconfig \
                        usr/lib/pkgconfig \
                        usr/lib/cmake \
                        lib/pkgconfig \
                        usr/share/aclocal
              fi
              makepkg -l y -c n $PKGFINAL
            )

            # cleanup package
            rm -rf $PKG

            # unset SOURCE_TAR
            SOURCE_TAR=
        )

        if [ $? -ne 0 ]; then
            echo "Error in $PKG_NAME.build"
            exit 1
        fi
    if [ -e $PKGFINALDEV ]; then
        echo "Installing on staging $i"
        ROOT=$STAGINGFS INSTLOCKDIR=$TMP/lock upgradepkg --reinstall --install-new $PKGFINALDEV #&> $PKG_LOGS/$PKG_NAME.install.log
    fi

    else
        echo "Skipping $1"
    fi
    cd $MAIN_DIR

}

buildrootfs() {
    for i in `find $OUTPUT_PKGS/{core,extra,lib,net,retroarch,kernel,$PLATFORM_NAME} -name *.t?z`; do
	ROOT=$ROOTFS INSTLOCKDIR=$TMP/lock upgradepkg --reinstall --install-new --terse $i
    done
    (
	cd $ROOTFS
        tar cvJf $OUTPUT_DIR/lilala-linux-rootfs-$SLK_BOARD.tar.xz .
    )
    echo "Filesystem size:"
    du -d 0 -h $ROOTFS
}

usage() {
    echo "usage: $0 [build|rebuild|delete|cleanfs|buildfs|rebuildfs]"
    echo ""
    echo "      build [package|buildlist]       build single or multiple package"
    echo "      rebuild [package|buildlist]     rebuild single or multiple package"
    echo "      delete [package|buildlist]      delete single or multiple package"
    echo "      cleanfs                         clean output filesystem"
    echo "      buildfs                         build output filesystem"
    echo "      rebuildfs                       rebuild output filesystem"
    exit 1
}

showbuildinfo() {

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

if [ -z "$SLK_BOARD" ]; then
    echo "Unknown board. Please check platform setup"
    exit 1
fi

PLATFORM_DIR=$PWD/platforms/$PLATFORM_NAME
OUTPUT_DIR=$MAIN_DIR/output/target-$SLK_LIBC-$SLK_ARCH
ROOTFS=$OUTPUT_DIR/rootfs-$SLK_BOARD
STAGINGFS=$OUTPUT_DIR/staging
KERNEL_DIR=$PLATFORM_DIR/kernel
OUTPUT_PKGS=$OUTPUT_DIR/pkgs
CACHE_DIR=$MAIN_DIR/cache
OUTPUT_STAGING_PKGS=$OUTPUT_DIR/staging_pkgs
OUTPUT_LOGS=$OUTPUT_DIR/logs
TMP=$PWD/build
PKGTYPE=tbz
TAG=lilala

mkdir -p $ROOTFS
mkdir -p $STAGINGFS
mkdir -p $CACHE_DIR

export PATH=$PWD/tools/:$SLK_TOOLCHAIN_PATH/bin:$PATH
export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR=$STAGINGFS/lib/pkgconfig:$STAGINGFS/usr/lib/pkgconfig
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
    buildimage)
        showbuildinfo
        rm -r $ROOTFS
        mkdir -p $ROOTFS
        buildrootfs
        buildimage
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

#ensure libc is builted
buildpkg core/$SLK_LIBC
buildpkg kernel/kernel
for i in `cat $OUTPUT_DIR/buildlist`; do
    if [ ! -z $DELETEPKG ]; then
        deletepkg $i
    fi
done
for i in `cat $OUTPUT_DIR/buildlist`; do
    if [ ! -z $BUILDPKG ]; then
        buildpkg $i
    fi
done
