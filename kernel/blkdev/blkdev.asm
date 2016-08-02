
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
BLKDEV_ATAPI			= 4
BLKDEV_SATAPI			= 5

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
; In\	AL = Device type
; In\	AH = Device content (partitioned/flat?)
; In\	EDX = Address
; Out\	EDX = Device number

blkdev_register:
	mov [.type], al

	mov edi, [blkdevs]
	shl edi, 3		; mul 8
	add edi, [blkdev_structure]
	mov [edi], al
	mov [edi+1], ah
	mov [edi+2], edx
	mov word[edi+6], 0

	mov esi, .msg
	call kprint

	mov al, [.type]
	cmp al, BLKDEV_ATA
	je .ata
	cmp al, BLKDEV_AHCI
	je .ahci
	cmp al, BLKDEV_RAMDISK
	je .ramdisk

.undefined:
	mov esi, .undefined_msg
	call kprint
	jmp .done

.ata:
	mov esi, .ata_msg
	call kprint
	jmp .done

.ahci:
	mov esi, .ahci_msg
	call kprint
	jmp .done

.ramdisk:
	mov esi, .ramdisk_msg
	call kprint

.done:
	mov esi, .msg2
	call kprint
	mov eax, [blkdevs]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	mov edx, [blkdevs]
	inc [blkdevs]
	ret

.type			db 0
.msg			db "Registered ",0
.ata_msg		db "ATA device",0
.ahci_msg		db "AHCI device",0
.ramdisk_msg		db "ramdisk device",0
.undefined_msg		db "undefined device",0
.msg2			db ", device number ",0



