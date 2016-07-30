
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; wm_pixel_offset:
; Returns pixel offset within window canvas
; In\	EAX = Window handle
; In\	CX/DX = X/Y pos within the window
; Out\	EAX = Pixel offset, -1 on error

wm_pixel_offset:
	mov [.x], cx
	mov [.y], dx

	call wm_get_window
	jc .error

	cmp [.x], si
	jge .error

	cmp [.y], di
	jge .error

	and esi, 0xFFFF		; window width
	shl esi, 2		; a canvas always uses 32bpp regardless of the physical video mode

	mov ebx, esi
	movzx eax, [.y]
	mul ebx

	movzx ebx, [.x]
	shl ebx, 2
	add eax, ebx
	add eax, ecx		; ecx = framebuffer address
	ret

.error:
	mov eax, -1
	ret

.x		dw 0
.y		dw 0

; wm_read_mouse:
; Reads the mouse position according to the window position
; In\	EAX = Window handle
; Out\	CX/DX = X/Y pos, 0 on error

wm_read_mouse:
	call wm_get_window
	jc .error

	mov ecx, [mouse_x]
	mov edx, [mouse_y]
	sub cx, ax
	sub dx, bx
	sub dx, 24

	test cx, 0x8000
	jnz .error
	test dx, 0x8000
	jnz .error
	ret

.error:
	xor cx, cx
	xor dx, dx
	ret

; wm_clear:
; Clears the window canvas
; In\	EAX = Window handle
; In\	EBX = Color
; Out\	Nothing

wm_clear:
	cli
	mov [.color], ebx

	call wm_get_window
	jc .done
	mov [.canvas], ecx	; ecx = base of window canvas

	movzx eax, si
	movzx ebx, di
	mul ebx
	mov ecx, eax		; ecx = size of canvas in pixels

	mov edi, [.canvas]
	mov eax, [.color]
	rep stosd

.done:
	call wm_redraw
	ret

.color			dd 0
.canvas			dd 0

; wm_render_char:
; Renders a character using the default system font
; In\	EAX = Window handle
; In\	BL = Character
; In\	CX/DX = X/Y pos
; In\	ESI = Color
; Out\	Nothing

wm_render_char:
	and esi, 0xFFFFFF
	mov [.fg], esi
	mov [.handle], eax

	and ebx, 0xFF
	shl ebx, 4
	add ebx, [system_font]
	mov [.font_data], ebx

	mov eax, [.handle]
	call wm_pixel_offset
	cmp eax, -1
	je .done
	mov [.offset], eax

	mov eax, [.handle]
	call wm_get_window
	jc .done
	and esi, 0xFFFF
	shl esi, 2		; mul 4
	mov [.line], esi	; bytes per line

	mov [.column], 0
	mov [.row], 0

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]
	mov edi, [.offset]

.put_column:
	test dl, 0x80
	jz .background

.foreground:
	mov eax, [.fg]
	stosd
	jmp .next_column

.background:
	add edi, 4

.next_column:
	inc [.column]
	cmp [.column], 8
	je .next_row

	shl dl, 1
	jmp .put_column

.next_row:
	inc [.row]
	cmp [.row], 16
	je .done

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]

	mov edi, [.line]
	add [.offset], edi
	mov edi, [.offset]
	jmp .put_column

.done:
	ret

.font_data		dd 0
.offset			dd 0
.column			db 0
.row			db 0
.fg			dd 0
.handle			dd 0
.line			dd 0

; wm_draw_text:
; Draws text using the default system font
; In\	EAX = Window Handle
; In\	ESI = Pointer to null terminated string
; In\	CX/DX = X/Y pos
; In\	EBX = Color
; Out\	Nothing

wm_draw_text:
	cli

	mov [.handle], eax
	mov [.x], cx
	mov [.y], dx
	mov [.ox], cx
	mov [.oy], dx
	mov [.color], ebx

.loop:
	lodsb
	or al, al
	jz .done
	cmp al, 13
	je .carriage
	cmp al, 10
	je .newline

	push esi
	mov bl, al		; bl = char
	mov eax, [.handle]
	mov cx, [.x]
	mov dx, [.y]
	mov esi, [.color]
	call wm_render_char
	pop esi

	add [.x], 8
	jmp .loop

.carriage:
	mov ax, [.ox]
	mov [.x], ax
	jmp .loop

.newline:
	mov ax, [.ox]
	mov [.x], ax
	add [.y], 16
	jmp .loop

.done:
	call wm_redraw
	ret

.handle			dd 0
.x			dw 0
.y			dw 0
.ox			dw 0
.oy			dw 0
.color			dd 0




