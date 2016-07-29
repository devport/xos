
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

REQUIRED_MEM			= 16*1024	; required memory in kilobytes

bios_boot_device		db 0
boot_partition:
	.boot			db 0
	.start_chs		db 0
				db 0
				db 0
	.type			db 0
	.end_chs		db 0
				db 0
				db 0
	.lba			dd 0
	.size			dd 0

bios_lomem			dw 0
bios_himem			dw 0
bios_pic1_mask			db 0
bios_pic2_mask			db 0
kernel_pic1_mask		db 0
kernel_pic2_mask		db 0

use16

; print16:
; Prints a string in 16-bit real mode
; In\	DS:SI = String
; Out\	Nothing

print16:
	pusha

.loop:
	lodsb
	cmp al, 0
	je .done
	cmp al, 10
	je .newline
	mov ah, 0xE
	int 0x10
	jmp .loop

.newline:
	mov ah, 0xE
	mov al, 13
	int 0x10
	mov al, 10
	int 0x10
	jmp .loop

.done:
	popa
	ret

; detect_memory:
; Detects memory

detect_memory:
	mov ax, 0xE801
	mov bx, 0
	mov cx, 0
	mov dx, 0
	int 0x15
	jc .error

	cmp ah, 0x86
	je .error

	cmp ah, 0x80
	je .error

	jcxz .use_ax

	mov ax, cx
	mov bx, dx

.use_ax:
	cmp ax, 0
	je .error

	mov [bios_lomem], ax
	mov [bios_himem], bx

	cmp ax, REQUIRED_MEM-1024
	jl .too_little

	ret

.error:
	mov si, .error_msg
	call print16

	cli
	hlt

.too_little:
	mov si, .too_little_msg
	call print16

	cli
	hlt

.error_msg			db "Boot error: Failed to detect memory.",0
.too_little_msg			db "Boot error: Too little memory available.",0

; enable_a20:
; Enables A20

enable_a20:
	mov ax, 0x2401		; try to use BIOS to enable A20
	int 0x15
	jc .try_quick

	cmp ah, 0x86
	je .try_quick

	cmp ah, 0x80
	je .try_quick

	ret

.try_quick:
	; try the PS/2 quick method
	in al, 0x92
	test al, 2
	jnz .done

	or al, 2
	and al, 0xFE
	out 0x92, al

	out 0x80, al
	out 0x80, al

.done:
	ret

; check_a20:
; Checks A20 status

check_a20:
	mov di, 0x500
	mov eax, 0
	stosd

	mov ax, 0xFFFF
	mov es, ax
	mov di, 0x510
	mov eax, "A20 "
	stosd

	mov ax, 0
	mov es, ax

	mov si, 0x500
	lodsd

	cmp eax, "A20 "
	je .bad

	ret

.bad:
	mov si, .error_msg
	call print16

	cli
	hlt

.error_msg			db "Boot error: A20 gate is not responding.",0




