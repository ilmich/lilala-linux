SLK_TOOLCHAIN_PATH=$MAIN_DIR/toolchains/armhf/
SLK_TARGET=arm-linux-musleabihf
SLK_STRIP_PKG="yes"

case $SLK_BOARD in
    rpi)
	SLK_ARCH=armv6j
	SLK_CFLAGS="-O2 -march=$SLK_ARCH -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard"
	;;
    rpi2|rpi3)
	SLK_ARCH=armv7a
	SLK_CFLAGS="-O2 -march=armv7-a -mfpu=neon -mfloat-abi=hard"
	;;
    rpi4)
	SLK_ARCH=armv8a
	SLK_CFLAGS="-O2 -march=armv8-a -mtune=cortex-a72 -mfpu=neon -mfloat-abi=hard -ftree-vectorize -pipe -fomit-frame-pointer"
	;;
    *)
	echo "Unknown board!!!"
	exit 1
	;;
esac
