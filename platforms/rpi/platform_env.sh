SLK_TOOLCHAIN_PATH=$MAIN_DIR/toolchains/armhf/
SLK_TARGET=arm-linux-musleabihf
SLK_STRIP_PKG="yes"

case $SLK_BOARD in
    rpi)
	SLK_ARCH=armv6
	SLK_CPU=arm1176jzf-s
	SLK_CFLAGS="-O2 -mcpu=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard"
	;;
    rpi2)
	SLK_ARCH=armv7a
	SLK_CPU=cortex-a7
	SLK_CFLAGS="-O2 -mcpu=cortex-a7 -mfpu=neon -mfloat-abi=hard"
	;;
    rpi3)
	SLK_ARCH=armv8a
	SLK_CPU=cortex-a53
	SLK_CFLAGS="-O2 -mcpu=cortex-a53 -mfpu=neon -mfloat-abi=hard"
	;;
    rpi4)
	SLK_ARCH=armv8a
	SLK_CPU=cortex-a72
	SLK_CFLAGS="-O2 -mcpu=cortex-a72 -mfpu=neon -mfloat-abi=hard -ftree-vectorize -pipe -fomit-frame-pointer"
	;;
    *)
	echo "Unknown board!!!"
	exit 1
	;;
esac
