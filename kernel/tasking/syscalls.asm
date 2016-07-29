
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

MAXIMUM_FUNCTION		= 0x0008

; Function Table ;)
align 16
api_table:
	dd wm_create_window	; 0x0000
	dd yield		; 0x0001
	dd wm_pixel_offset	; 0x0002
	dd wm_redraw		; 0x0003
	dd wm_read_event	; 0x0004
	dd wm_read_mouse	; 0x0005
	dd wm_render_char	; 0x0006
	dd wm_draw_text		; 0x0007
	dd wm_clear		; 0x0008

; syscall_init:
; Installs the kernel API interrupt vector

syscall_init:
	mov al, 0x60		; int 0x60
	mov ebp, kernel_api
	call install_isr

	mov al, 0x60
	mov dl, 0xEE		; set interrupt privledge to userspace
	call set_isr_privledge

	ret

; kernel_api:
; INT 0x60 Handler
; In\	EBP = Function code
; In\	All other registers = Depends on function input
; Out\	All registers = Depends on function output; all undefined registers destroyed

kernel_api:
	cmp ebp, MAXIMUM_FUNCTION
	jg .done

	sti

	shl ebp, 2	; mul 4
	add ebp, api_table
	mov ebp, [ebp]
	call ebp

.done:
	iret




