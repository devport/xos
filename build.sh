#!/bin/sh
mkdir out
#fasm boot/mbr.asm out/mbr.bin
#fasm boot/boot_hdd.asm out/boot_hdd.bin
fasm kernel/kernel.asm out/kernel32.sys
#fasm tmp/root.asm
#dd if=out/mbr.bin conv=notrunc bs=512 count=1 conv=notrunc of=disk.img
#dd if=out/boot_hdd.bin conv=notrunc bs=512 seek=63 conv=notrunc of=disk.img
#dd if=tmp/root.bin conv=notrunc bs=512 seek=64 conv=notrunc of=disk.img
dd if=out/kernel32.sys conv=notrunc bs=512 seek=200 conv=notrunc of=disk.img

