SLK_TOOLCHAIN_PATH=$MAIN_DIR/toolchains/armhf/
SLK_TARGET=arm-linux-musleabihf
SLK_STRIP_PKG="yes"
SLK_LIBC="musl"

case $SLK_BOARD in
    rpi)
	SLK_ARCH=armv6k
	SLK_CPU=arm1176jzf-s
	SLK_CFLAGS="-O2 -march=armv6k+fp -mfpu=vfp -mfloat-abi=hard"
	;;
    rpi2|rpi3|rpi4)
	SLK_ARCH=armv7a
	SLK_CPU=cortex-a7
	SLK_CFLAGS="-O2 -march=armv7-a -mfpu=neon -mfloat-abi=hard"
	;;
    *)
	echo "Unknown board!!!"
	exit 1
	;;
esac

# just for future development... in a linux system with package manager it's hard to mantain different repos for each architecture
#    rpi3)
#	SLK_ARCH=armv8a
#	SLK_CPU=cortex-a53
#	SLK_CFLAGS="-O2 -march=armv8-a+crc+crypto -mtune=cortex-a53 -mfpu=crypto-neon-fp-armv8 -mfloat-abi=hard -ftree-vectorize -pipe -fomit-frame-pointer"
#	;;
#   rpi4)
#	SLK_ARCH=armv8a
#	SLK_CPU=cortex-a72
#	SLK_CFLAGS="-O2 -march=armv8-a+crc+crypto -mtune=cortex-a72 -mfpu=crypto-neon-fp-armv8 -mfloat-abi=hard -ftree-vectorize -pipe -fomit-frame-pointer"
#	;;
