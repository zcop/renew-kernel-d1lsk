#!/bin/bash

defconfig=renew_defconfig
toolchaindir=~/android-toolchain/arm-cortex_a15-linux-gnueabihf-linaro_4.9.2-2014.09
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
RESET=$(tput sgr0)

export ARCH=arm
export TARGET_PRODUCT=d1lsk_SKT_KR
export CROSS_COMPILE=$toolchaindir/bin/arm-eabi-

build-kernel(){
	[ -e arch/arm/boot/zImage ] && rm arch/arm/boot/zImage

	make -j16

	if [ -e .config.bak ]; then
		rm .config
		mv .config.bak .config
	fi

	if [ -e arch/arm/boot/zImage ]; then
		echo "$BOLD""$GREEN"Compressing ramdisk"$RESET"
		[ -e initrd.lz4 ] && rm initrd.lz4
		cd ramdisk
		find . \( ! -regex '.*/\..*' \) | cpio -o -H newc -R root:root | ../lz4c -l -c1 stdin ../initrd.lz4
		cd ..

		echo "$BOLD""$GREEN"Making boot.img"$RESET"
		./mkbootimg --kernel arch/arm/boot/zImage --ramdisk initrd.lz4 --base 0x80200000 --ramdisk_offset 0x02000000 --pagesize 2048 --cmdline "console=ttyHSL0,115200,n8 androidboot.hardware=d1lsk user_debug=31 msm_rtb.filter=0x3F ehci-hcd.park=3 lpj=67724" --output out/boot.img

		echo "$BOLD""$GREEN"Copying modules"$RESET"
		mkdir -p out/system/lib/modules/prima
		dd if=drivers/staging/prima/wlan.ko of=out/system/lib/modules/prima/prima_wlan.ko
		dd if=net/wireless/cfg80211.ko of=out/system/lib/modules/prima/cfg80211.ko
		"$CROSS_COMPILE"strip --strip-unneeded out/system/lib/modules/prima/*.ko

		echo "$BOLD""$GREEN"Making flashable ZIP"$RESET"
		cd out
		[ -e $outzip.zip ] && rm $outzip.zip
		zip -r $outzip.zip * -x *.zip
		cd ..
	else
		echo "$BOLD""$RED"BUILD FAILED!!"$RESET"
	fi
}

if [ "$1" == "build" ]; then
	if [ "$2" != "nooc" -a "$2" != "oc1" -a "$2" != "oc2" -a "$2" != "all" ]; then
		echo "Build type must be specified!! (nooc/oc1/oc2/all)"
		exit
	fi

	if [ ! -e .config ]; then
		echo "$BOLD""$GREEN"Writing defconfig"$RESET"
		make $defconfig
	fi

	cp .config .config.bak

	if [ "$2" == "nooc" ]; then
		echo "$BOLD""$GREEN"Launching build w/o CPU OC"$RESET"
		outzip=ReNew
	elif [ "$2" == "oc1" ]; then
		sed -i 's/# CONFIG_CPU_OVERCLOCK is not set/CONFIG_CPU_OVERCLOCK=y\n# CONFIG_OC_ULTIMATE is not set/' .config
		echo "$BOLD""$GREEN"Launching build with CPU OC Lv 1"$RESET"
		outzip=ReNew_1.8oc
	elif [ "$2" == "oc2" ]; then
		sed -i 's/# CONFIG_CPU_OVERCLOCK is not set/CONFIG_CPU_OVERCLOCK=y\nCONFIG_OC_ULTIMATE=y/' .config
		echo "$BOLD""$GREEN"Launching build with CPU OC Lv 2"$RESET"
		outzip=ReNew_1.9oc
	elif [ "$2" == "all" ]; then
		# First build
		echo "$BOLD""$GREEN"Launching first build w/o CPU OC"$RESET"
		outzip=Renew
	fi

	build-kernel

	if [ "$2" == "all" ]; then
		# Second build with OC Lv 1
		cp .config .config.bak
		sed -i 's/# CONFIG_CPU_OVERCLOCK is not set/CONFIG_CPU_OVERCLOCK=y\n# CONFIG_OC_ULTIMATE is not set/' .config
		echo "$BOLD""$GREEN"Launching second build with CPU OC Lv 1"$RESET"
		outzip=ReNew_1.8oc

		build-kernel

		# Final build with OC Lv 2
		cp .config .config.bak
		sed -i 's/# CONFIG_CPU_OVERCLOCK is not set/CONFIG_CPU_OVERCLOCK=y\nCONFIG_OC_ULTIMATE=y/' .config
		echo "$BOLD""$GREEN"Launching final build with CPU OC Lv 2"$RESET"
		outzip=ReNew_1.9oc

		build-kernel
	fi
elif [ "$1" == "clean" ]; then
	make -j16 mrproper
	if [ -e out/boot.img ]; then
		echo "  CLEAN   out/boot.img"
		rm -f out/boot.img
		echo "  CLEAN   out/modules"
		rm -rf out/system/lib
		echo "  CLEAN   boot.img-ramdisk.lz4"
	fi
else
	echo "usage: ./build.sh [build/clean] [nooc/oc1/oc2/all]"
fi
