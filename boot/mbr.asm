
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.
;; boot/mbr.asm -- Master Boot Record

use16
org 0

relocate:
	cli
	cld

	mov ax, 0
	mov ds, ax
	mov es, ax

	mov si, 0x7C00
	mov di, 0x600
	mov cx, 512
	rep movsb

	jmp 0x60:main

main:
	mov ax, 0x60
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0
	sti

	mov [bootdisk], dl

	mov ah, 0xF
	int 0x10

	cmp al, 3
	je start_booting

	cmp al, 7
	je start_booting

	mov ax, 3
	int 0x10

start_booting:
	mov ax, 0
	mov dl, [bootdisk]
	int 0x13
	jc disk_error

	test byte[part1.boot], 0x80
	jnz .boot1

	test byte[part2.boot], 0x80
	jnz .boot2

	test byte[part3.boot], 0x80
	jnz .boot3

	test byte[part4.boot], 0x80
	jnz .boot4

	mov si, _no_active_partition
	call print

	jmp $

.boot1:
	mov si, part1
	jmp load_boot_sector

.boot2:
	mov si, part2
	jmp load_boot_sector

.boot3:
	mov si, part3
	jmp load_boot_sector

.boot4:
	mov si, part4

load_boot_sector:
	push si
	add si, 8
	mov eax, dword[si]
	mov [dap.lba], eax

	mov ah, 0x42
	mov dl, [bootdisk]
	mov si, dap
	int 0x13
	jc disk_error

	pop si
	mov dl, [bootdisk]
	jmp 0:0x7C00

disk_error:
	mov si, _disk_error
	call print

	jmp $

print:
	mov ah, 0xE

.loop:
	lodsb
	cmp al, 0
	je .done
	int 0x10
	jmp .loop

.done:
	ret

align 4

dap:
	.size			db 0x10
	.reserved		db 0
	.sectors		dw 1
	.offset			dw 0x7C00
	.segment		dw 0
	.lba			dd 0
				dd 0

bootdisk			db 0

_disk_error			db "Disk I/O failure.",0
_no_active_partition		db "No active partition found.",0

times 0x1BE - ($-$$) db 0

part1:
	.boot			db 0x80
	.chs			db 1
				db 1
				db 0
	.type			db 0xF3
	.end_chs		db 59
				db 9
				db 25
	.lba			dd 63
	.size			dd 60000

part2:
	.boot			db 0
	.chs			db 0
				db 0
				db 0
	.type			db 0
	.end_chs		db 0
				db 0
				db 0
	.lba			dd 0
	.size			dd 0

part3:
	.boot			db 0
	.chs			db 0
				db 0
				db 0
	.type			db 0
	.end_chs		db 0
				db 0
				db 0
	.lba			dd 0
	.size			dd 0

part4:
	.boot			db 0
	.chs			db 0
				db 0
				db 0
	.type			db 0
	.end_chs		db 0
				db 0
				db 0
	.lba			dd 0
	.size			dd 0

dw 0xAA55
