#!/bin/sh

MAIN_DIR=$PWD

if [ "$1" == "" ]; then
    echo "Usage $0 platform_name"
    exit 1
fi

if [ ! -e $PWD/platforms/$1/platform_env.sh ]; then
    echo "Platform $1 not exists"
    exit 1
fi

. $PWD/platforms/$1/platform_env.sh
OUTPUT_DIR=$MAIN_DIR/output
mkdir -p $OUTPUT_DIR
echo $1 > $OUTPUT_DIR/platform

echo "Building lilala linux for $1"
echo "Target :$SLK_TARGET"
echo "Arch: $SLK_ARCH"
echo "Compiler Flags: $SLK_CFLAGS"
