
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

;
; struct blkdev {
; u8 device_type;		// 00
; u8 device_content;		// 01
; u32 address;			// 02
; u16 padding;			// 06
; };
;
;
; sizeof(blkdev) = 8;
;

BLKDEV_DEVICE_TYPE		= 0x00
BLKDEV_DEVICE_CONTENT		= 0x01
BLKDEV_ADDRESS			= 0x02
BLKDEV_PADDING			= 0x06
BLKDEV_SIZE			= 0x08

; System can manage up to 64 block devices
MAXIMUM_BLKDEVS			= 64

; Device Type
BLKDEV_UNPRESENT		= 0
BLKDEV_ATA			= 1
BLKDEV_AHCI			= 2
BLKDEV_RAMDISK			= 3

; Device Content
BLKDEV_FLAT			= 0
BLKDEV_PARTITIONED		= 1

blkdev_structure		dd 0
blkdevs				dd 0	; number of block devices on the system

; blkdev_init:
; Detects and initializes block devices

blkdev_init:
	mov ecx, MAXIMUM_BLKDEVS*BLKDEV_SIZE
	call kmalloc
	mov [blkdev_structure], eax

	; detect devices ;)
	call ata_detect
	;call ahci_detect
	;call usb_mass_detect

	ret

; blkdev_register:
; Registers a device

blkdev_register:
	ret


