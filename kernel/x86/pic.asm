
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

IRQ_BASE			= 0x30

; pic_init:
; Initializes the PIC

pic_init:
	mov esi, .starting_msg
	call kprint

	mov al, IRQ_BASE
	mov ah, IRQ_BASE+8
	call pic_remap

	; cascade
	mov al, IRQ_BASE+2
	mov ebp, pic_cascade
	call install_isr

	; master spurious
	mov al, IRQ_BASE+7
	mov ebp, pic1_spurious
	call install_isr

	; slave spurious
	mov al, IRQ_BASE+15
	mov ebp, pic2_spurious
	call install_isr

	; unmask the cascade IRQ so that IRQs from the slave PIC can happen
	mov al, 2
	call pic_unmask

	sti

	mov al, 0x20
	out 0x20, al
	out 0xA0, al

	ret

.starting_msg			db "Reprogamming IRQs...",10,0

; pic_cascade:
; IRQ 2 (Cascade) Handler

pic_cascade:
	iret

; pic1_spurious:
; IRQ 7 (Master Spurious) Handler

pic1_spurious:
	push eax

	mov al, 0x0B	; read ISR register
	out 0x20, al
	call iowait
	in al, 0x20

	test al, 0x80
	jz .quit

	mov al, 0x20
	out 0x20, al

.quit:
	pop eax
	iret

; pic2_spurious:
; IRQ 15 (Slave Spurious) Handler

pic2_spurious:
	push eax

	mov al, 0x0B
	out 0xA0, al
	call iowait
	in al, 0xA0

	test al, 0x80
	jz .quit

	mov al, 0x20
	out 0xA0, al

.quit:
	mov al, 0x20
	out 0x20, al

	pop eax
	iret

; pic_remap:
; Remaps the PIC
; In\	AL = Master PIC Vector
; In\	AH = Slave PIC Vector
; Out\	Nothing

pic_remap:
	mov [.master], al
	mov [.slave], ah

	; save masks
	in al, 0x21
	mov [.data1], al
	call iowait
	in al, 0xA1
	mov [.data2], al
	call iowait

	mov al, 0x11			; initialize command
	out 0x20, al
	call iowait
	mov al, 0x11
	out 0xA0, al
	call iowait

	mov al, [.master]
	out 0x21, al
	call iowait
	mov al, [.slave]
	out 0xA1, al
	call iowait

	mov al, 4
	out 0x21, al
	call iowait
	mov al, 2
	out 0xA1, al
	call iowait

	mov al, 1
	out 0x21, al
	call iowait
	mov al, 1
	out 0xA1, al
	call iowait

	; restore masks
	mov al, [.data1]
	out 0x21, al
	call iowait
	mov al, [.data2]
	out 0xA1, al
	call iowait

	ret

.master				db 0
.slave				db 0
.data1				db 0
.data2				db 0

; pic_mask:
; Masks an IRQ
; In\	AL = IRQ number
; Out\	Nothing

pic_mask:
	cmp al, 8
	jge .slave

.master:
	mov cl, al
	mov dl, 1
	shl dl, cl

	in al, 0x21
	or al, dl
	out 0x21, al

	ret

.slave:
	sub al, 8
	mov cl, al
	mov dl, 1
	shl dl, cl

	in al, 0xA1
	or al, dl
	out 0xA1, al

	ret

; pic_unmask:
; Unmasks a PIC IRQ
; In\	AL = IRQ
; Out\	Nothing

pic_unmask:
	cmp al, 8
	jge .slave

.master:
	mov cl, al
	mov dl, 1
	shl dl, cl

	in al, 0x21
	not dl
	and al, dl
	out 0x21, al

	ret

.slave:
	sub al, 8
	mov cl, al
	mov dl, 1
	shl dl, cl

	in al, 0xA1
	not dl
	and al, dl
	out 0xA1, al

	ret
	


