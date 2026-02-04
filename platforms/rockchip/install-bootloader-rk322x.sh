install () {
    echo "image: burn idbloader.img to image..."
    dd if=$PLATFORM_DIR/bootloaders/rk322x-idbloader.img of=$1 bs=32k seek=1 conv=fsync,notrunc
    echo "image: burn uboot.img to image..."
    dd if=$PLATFORM_DIR/bootloaders/rk322x-uboot.img of=$1 bs=64k seek=128 conv=fsync,notrunc
    echo "image: burn trust.img to image..."
    dd if=$PLATFORM_DIR/bootloaders/rk322x-trust.img of=$1 bs=64k seek=192 conv=fsync,notrunc
}