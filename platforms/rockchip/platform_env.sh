SLK_TOOLCHAIN_PATH=$MAIN_DIR/toolchains/armhf/
SLK_TARGET=arm-linux-musleabihf
SLK_STRIP_PKG="yes"
SLK_LIBC="musl"

case $SLK_BOARD in
    rk322x)
	SLK_ARCH=armv7a
	SLK_CPU=armv7-a
	SLK_CFLAGS="-O2 -march=armv7-a -mfpu=neon -mfloat-abi=hard"
	;;
    *)
	echo "Unknown board!!!"
	exit 1
	;;
esac
