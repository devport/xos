
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; xOS GDI -- An internal graphics library used by the xOS Kernel
; Should be easy to port to other systems

is_redraw_enabled		db 1
text_background			dd 0x000000
text_foreground			dd 0xFFFFFF
system_font			dd font
current_buffer			db 0		; 0 if the system is using the back buffer
						; 1 if it's using the hardware buffer

; redraw_screen:
; Redraws the screen

redraw_screen:
	test [is_redraw_enabled], 1
	jz .quit
	test [current_buffer], 1
	jnz .quit

	mov esi, VBE_BACK_BUFFER
	mov edi, VBE_PHYSICAL_BUFFER
	mov ecx, [screen.screen_size_dqwords]

.loop:
	movdqa xmm0, [esi]
	movdqa xmm1, [esi+0x10]
	movdqa xmm2, [esi+0x20]
	movdqa xmm3, [esi+0x30]
	movdqa xmm4, [esi+0x40]
	movdqa xmm5, [esi+0x50]
	movdqa xmm6, [esi+0x60]
	movdqa xmm7, [esi+0x70]

	movdqa [edi], xmm0
	movdqa [edi+0x10], xmm1
	movdqa [edi+0x20], xmm2
	movdqa [edi+0x30], xmm3
	movdqa [edi+0x40], xmm4
	movdqa [edi+0x50], xmm5
	movdqa [edi+0x60], xmm6
	movdqa [edi+0x70], xmm7

	add esi, 128
	add edi, 128
	loop .loop

.quit:
	ret

; use_back_buffer:
; Forces the system to use the back buffer

use_back_buffer:
	mov [current_buffer], 0
	ret

; use_front_buffer:
; Forces the system to use the hardware framebuffer

use_front_buffer:
	mov [current_buffer], 1
	ret

; lock_screen:
; Prevents screen redraws while using the back buffer

lock_screen:
	mov [is_redraw_enabled], 0	
	ret

; unlock_screen:
; Enables screen redraws while using the back buffer

unlock_screen:
	mov [is_redraw_enabled], 1
	ret

; get_pixel_offset:
; Gets pixel offset
; In\	AX/BX = X/Y pos
; Out\	ESI = Offset within hardware framebuffer
; Out\	EDI = Offset within back buffer
; Note:
; If the system is using the hardware framebuffer (i.e. current_buffer is set to 1), ESI and EDI are swapped.
; This tricks the GDI into writing directly to the hardware framebuffer, and preventing manual screen redraws.
; This is needed for the mouse cursor. ;)

get_pixel_offset:
	mov [.x], ax
	mov [.y], bx

	movzx eax, [.y]
	mov ebx, [screen.bytes_per_line]
	mul ebx

	push eax

	movzx eax, [.x]
	mov ebx, [screen.bytes_per_pixel]
	mul ebx

	pop ebx
	add eax, ebx

	mov esi, eax
	mov edi, eax

	add esi, VBE_PHYSICAL_BUFFER
	add edi, VBE_BACK_BUFFER

	test [current_buffer], 1
	jnz .swap
	ret

.swap:
	xchg esi, edi	; swap ;)
	ret

.x			dw 0
.y			dw 0

; put_pixel:
; Puts a pixel
; In\	AX/BX = X/Y pos
; In\	EDX = Color
; Out\	Nothing

put_pixel:
	push edx
	call get_pixel_offset

	pop eax
	cmp [screen.bpp], 32
	je .32

.24:
	stosw
	shr eax, 16
	stosb

	call redraw_screen
	ret

.32:
	stosd
	call redraw_screen
	ret

; clear_screen:
; Clears the screen
; In\	EBX = Color
; Out\	Nothing

clear_screen:
	mov [screen.x], 0
	mov [screen.y], 0

	cmp [screen.bpp], 32
	je .32

.24:
	mov edi, VBE_BACK_BUFFER
	mov ecx, [screen.screen_size]

.24_loop:
	mov eax, ebx
	stosw
	shr eax, 16
	stosb
	loop .24_loop

	call redraw_screen
	ret

.32:
	mov edi, VBE_BACK_BUFFER
	mov ecx, [screen.screen_size]
	shr ecx, 2
	mov eax, ebx
	rep stosd

	call redraw_screen
	ret

; render_char:
; Renders a character
; In\	AL = Character
; In\	CX/DX = X/Y pos
; In\	ESI = Font data
; Out\	Nothing

render_char:
	cmp [screen.bpp], 32
	je render_char32

	jmp render_char24

render_char32:
	and eax, 0xFF
	shl eax, 4
	add eax, esi
	mov [.font_data], eax

	mov ax, cx
	mov bx, dx
	call get_pixel_offset

	xor dl, dl
	mov [.row], dl
	mov [.column], dl

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]

.put_column:
	;mov dl, [.byte]
	test dl, 0x80
	jz .background

.foreground:
	mov eax, [text_foreground]
	jmp .put

.background:
	mov eax, [text_background]

.put:
	stosd
	jmp .next_column

.next_column:
	inc [.column]
	cmp [.column], 8
	je .next_row

	shl dl, 1
	jmp .put_column

.next_row:
	mov [.column],0
	inc [.row]
	cmp [.row], 16
	je .done

	mov eax, [screen.bytes_per_pixel]
	shl eax, 3
	sub edi, eax
	add edi, [screen.bytes_per_line]

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]
	jmp .put_column

.done:
	ret

.font_data			dd 0
.row				db 0
.column				db 0

render_char24:
	and eax, 0xFF
	shl eax, 4
	add eax, esi
	mov [.font_data], eax

	mov ax, cx
	mov bx, dx
	call get_pixel_offset

	xor dl, dl
	mov [.row], dl
	mov [.column], dl

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]

.put_column:
	;mov dl, [.byte]
	test dl, 0x80
	jz .background

.foreground:
	mov eax, [text_foreground]
	jmp .put

.background:
	mov eax, [text_background]

.put:
	stosw
	shr eax, 16
	stosb
	jmp .next_column

.next_column:
	inc [.column]
	cmp [.column], 8
	je .next_row

	shl dl, 1
	jmp .put_column

.next_row:
	mov [.column],0
	inc [.row]
	cmp [.row], 16
	je .done

	mov eax, [screen.bytes_per_pixel]
	shl eax, 3
	sub edi, eax
	add edi, [screen.bytes_per_line]

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]
	jmp .put_column

.done:
	ret

.font_data			dd 0
.row				db 0
.column				db 0


; render_char_transparent:
; Renders a character with transparent background
; In\	AL = Character
; In\	CX/DX = X/Y pos
; In\	ESI = Font data
; Out\	Nothing

render_char_transparent:
	cmp [screen.bpp], 32
	je render_char_transparent32

	jmp render_char_transparent24

render_char_transparent32:
	and eax, 0xFF
	shl eax, 4
	add eax, esi
	mov [.font_data], eax

	mov ax, cx
	mov bx, dx
	call get_pixel_offset

	xor dl, dl
	mov [.row], dl
	mov [.column], dl

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]

.put_column:
	;mov dl, [.byte]
	test dl, 0x80
	jz .background

.foreground:
	mov eax, [text_foreground]

.put:
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
	mov [.column],0
	inc [.row]
	cmp [.row], 16
	je .done

	sub edi, 8*4
	add edi, [screen.bytes_per_line]

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]
	jmp .put_column

.done:
	ret

.font_data			dd 0
.row				db 0
.column				db 0

render_char_transparent24:
	and eax, 0xFF
	shl eax, 4
	add eax, esi
	mov [.font_data], eax

	mov ax, cx
	mov bx, dx
	call get_pixel_offset

	xor dl, dl
	mov [.row], dl
	mov [.column], dl

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]

.put_column:
	;mov dl, [.byte]
	test dl, 0x80
	jz .background

.foreground:
	mov eax, [text_foreground]

.put:
	stosw
	shr eax, 16
	stosb
	jmp .next_column

.background:
	add edi, 3

.next_column:
	inc [.column]
	cmp [.column], 8
	je .next_row

	shl dl, 1
	jmp .put_column

.next_row:
	mov [.column],0
	inc [.row]
	cmp [.row], 16
	je .done

	sub edi, 8*3
	add edi, [screen.bytes_per_line]

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]
	jmp .put_column

.done:
	ret

.font_data			dd 0
.row				db 0
.column				db 0

; set_font:
; Sets the system font
; In\	ESI = 4k buffer to use as font
; Out\	Nothing

set_font:
	mov [system_font], esi
	ret

; set_text_color:
; Sets the text color
; In\	EBX = Background
; In\	ECX = Foreground
; Out\	Nothing

set_text_color:
	and ebx, 0xFFFFFF
	and ecx, 0xFFFFFF
	mov [text_background], ebx
	mov [text_foreground], ecx
	ret

; print_string:
; Prints a string
; In\	ESI = String
; In\	CX/DX = X/Y pos
; Out\	Nothing

print_string:
	mov [.x], cx
	mov [.y], dx
	mov [.ox], cx
	mov [.oy], dx

.loop:
	lodsb
	or al, al
	jz .done
	cmp al, 13
	je .carriage
	cmp al, 10
	je .newline

	push esi
	mov cx, [.x]
	mov dx, [.y]
	mov esi, [system_font]
	call render_char
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
	call redraw_screen
	ret

.x				dw 0
.y				dw 0
.ox				dw 0
.oy				dw 0

; print_string_transparent:
; Prints a string with transparent background
; In\	ESI = String
; In\	CX/DX = X/Y pos
; Out\	Nothing

print_string_transparent:
	mov [.x], cx
	mov [.y], dx
	mov [.ox], cx
	mov [.oy], dx

.loop:
	lodsb
	or al, al
	jz .done
	cmp al, 13
	je .carriage
	cmp al, 10
	je .newline

	push esi
	mov cx, [.x]
	mov dx, [.y]
	mov esi, font
	call render_char_transparent
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
	call redraw_screen
	ret

.x				dw 0
.y				dw 0
.ox				dw 0
.oy				dw 0

; scroll_screen:
; Scrolls the screen

scroll_screen:
	pusha

	mov esi, [screen.bytes_per_line]
	shl esi, 4		; mul 16
	add esi, VBE_BACK_BUFFER
	mov edi, VBE_BACK_BUFFER
	mov ecx, [screen.screen_size]
	call memcpy

	mov [screen.x], 0
	mov eax, [screen.y_max]
	mov [screen.y], eax

	popa
	ret

; put_char:
; Puts a char at cursor position
; In\	AL = Character
; Out\	Nothing

put_char:
	pusha

	cmp al, 13
	je .carriage
	cmp al, 10
	je .newline

.start:
	mov edx, [screen.x_max]
	cmp [screen.x], edx
	jg .new_y

	mov edx, [screen.y_max]
	cmp [screen.y], edx
	jg .scroll

	mov ecx, [screen.x]
	mov edx, [screen.y]
	shl ecx, 3
	shl edx, 4
	mov esi, [system_font]
	call render_char

	inc [screen.x]

.done:
	call redraw_screen
	popa
	ret

.new_y:
	mov [screen.x], 0
	inc [screen.y]
	mov edx, [screen.y_max]
	cmp [screen.y], edx
	jg .scroll

	jmp .start

.scroll:
	call scroll_screen
	jmp .start

.carriage:
	mov [screen.x], 0
	jmp .done

.newline:
	mov [screen.x], 0
	inc [screen.y]
	mov edx, [screen.y_max]
	cmp [screen.y], edx
	jg .scroll_newline

	jmp .done

.scroll_newline:
	call scroll_screen
	jmp .done

; fill_rect:
; Fills a rectangle
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	EDX = Color
; Out\	Nothing

fill_rect:
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.color], edx

	movzx eax, [.width]
	mov ebx, [screen.bytes_per_pixel]
	mul ebx
	mov [.bytes_per_line], eax		; one line of rect

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

	mov [.current_line], 0

.loop:
	mov edi, [.offset]
	mov eax, [.color]
	mov ecx, [.bytes_per_line]
	cmp [screen.bpp], 32
	je .32

.24:
	mov eax, [.color]
	stosw
	shr eax, 16
	stosb
	sub ecx, 3
	cmp ecx, 3
	jl .next_line
	jmp .24

.32:
	shr ecx, 2
	rep stosd

.next_line:
	inc [.current_line]
	mov cx, [.height]
	cmp [.current_line], cx
	jge .done

	mov eax, [screen.bytes_per_line]
	add [.offset], eax
	jmp .loop

.done:
	call redraw_screen
	ret

.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.color				dd 0
.offset				dd 0
.bytes_per_line			dd 0
.current_line			dw 0

; blit_buffer:
; Blits a pixel buffer
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	ECX = Transparent color
; In\	EDX = Pixel buffer
; Out\	Nothing

blit_buffer:
	mov [.transparent], ecx
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	add ax, si
	add bx, di
	mov [.end_x], ax
	mov [.end_y], bx
	mov [.buffer], edx
	mov [.current_line], 0

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

	cmp [screen.bpp], 24
	je .24

.32:
	mov esi, [.buffer]
	mov edi, [.offset]
	movzx ecx, [.width]
	mov edx, [.transparent]

.32_loop:
	lodsd
	cmp eax, edx
	je .32_skip
	stosd
	loop .32_loop

	jmp .32_done

.32_skip:
	add edi, 4
	loop .32_loop

.32_done:
	mov [.buffer], esi

	mov eax, [screen.bytes_per_line]
	add [.offset], eax
	inc [.current_line]
	movzx eax, [.height]
	cmp [.current_line], eax
	jge .done

	jmp .32

.24:
	mov esi, [.buffer]
	mov edi, [.offset]
	movzx ecx, [.width]
	mov edx, [.transparent]

.24_loop:
	lodsd
	cmp eax, edx
	je .24_skip
	stosw
	shr eax, 16
	stosb
	loop .24_loop
	jmp .24_done

.24_skip:
	add edi, 3
	loop .24_loop

.24_done:
	mov [.buffer], esi

	mov eax, [screen.bytes_per_line]
	add [.offset], eax
	inc [.current_line]
	movzx eax, [.height]
	cmp [.current_line], eax
	jge .done

	jmp .24

.done:
	call redraw_screen
	ret

.transparent			dd 0
.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.end_x				dw 0
.end_y				dw 0
.buffer				dd 0
.offset				dd 0
.current_line			dd 0

; blit_buffer_no_transparent:
; Blits a pixel buffer (same as above, but without support for transparent colors)
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	EDX = Pixel buffer
; Out\	Nothing

blit_buffer_no_transparent:
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	add ax, si
	add bx, di
	mov [.end_x], ax
	mov [.end_y], bx
	mov [.buffer], edx
	mov [.current_line], 0

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

	cmp [screen.bpp], 24
	je .24

.32:
	mov esi, [.buffer]
	mov edi, [.offset]
	movzx ecx, [.width]

.32_loop:
	shl ecx, 2
	call memcpy	; SSE memcpy

.32_done:
	mov [.buffer], esi

	mov eax, [screen.bytes_per_line]
	add [.offset], eax
	inc [.current_line]
	movzx eax, [.height]
	cmp [.current_line], eax
	jge .done

	jmp .32

.24:
	mov esi, [.buffer]
	mov edi, [.offset]
	movzx ecx, [.width]

.24_loop:
	movsw
	movsb
	inc esi
	loop .24_loop
	jmp .24_done

.24_done:
	mov [.buffer], esi

	mov eax, [screen.bytes_per_line]
	add [.offset], eax
	inc [.current_line]
	movzx eax, [.height]
	cmp [.current_line], eax
	jge .done

	jmp .24

.done:
	call redraw_screen
	ret

.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.end_x				dw 0
.end_y				dw 0
.buffer				dd 0
.offset				dd 0
.current_line			dd 0


; decode_bmp:
; Decodes a 24-bit BMP image
; In\	EDX = Pointer to image data
; In\	EBX = Pointer to memory location to store raw pixel buffer
; Out\	ECX = Size of raw pixel buffer in bytes, -1 on error
; Out\	SI/DI = Width/Height of image

decode_bmp:
	mov [.image], edx
	mov [.memory], ebx

	mov esi, [.image]
	cmp word[esi], "BM"	; bmp image signature
	jne .bad

	mov esi, [.image]
	mov eax, [esi+18]
	mov [.width], eax
	mov eax, [esi+22]
	mov [.height], eax

	mov eax, [.width]
	mov ebx, [.height]
	mul ebx
	mov [.size_pixels], eax
	shl eax, 2
	mov [.buffer_size], eax

	mov esi, [.image]
	add esi, 10
	mov esi, [esi]
	add esi, [.image]
	mov edi, [.memory]
	mov ecx, [.size_pixels]

.copy_loop:
	movsw
	movsb
	mov al, 0
	stosb
	loop .copy_loop

.done:
	mov edx, [.memory]
	mov esi, [.width]
	mov edi, [.height]
	call invert_buffer_vertically

	mov esi, [.width]
	mov edi, [.height]
	mov ecx, [.buffer_size]
	ret

.bad:
	mov ecx, -1
	mov esi, 0
	mov edi, 0
	ret

.image				dd 0
.memory				dd 0
.width				dd 0
.height				dd 0
.size_pixels			dd 0
.buffer_size			dd 0

; invert_buffer_vertically:
; Inverts a pixel buffer vertically
; In\	EDX = Pointer to pixel data
; In\	SI/DI = Width/Height
; Out\	Buffer inverted

invert_buffer_vertically:
	mov [.buffer], edx
	mov [.width], si
	mov [.height], di

	movzx eax, [.width]
	shl eax, 2
	mov [.bytes_per_line], eax

	movzx eax, [.height]
	dec eax
	mov ebx, [.bytes_per_line]
	mul ebx
	add eax, [.buffer]
	mov [.last_line], eax

	mov esi, [.buffer]
	mov edi, [.last_line]

.loop:
	cmp esi, edi
	jge .done

	mov ecx, [.bytes_per_line]
	call memxchg

	add esi, [.bytes_per_line]
	sub edi, [.bytes_per_line]
	jmp .loop

.done:
	ret

.buffer					dd 0
.width					dw 0
.height					dw 0
.current_row				dd 0
.current_line				dd 0
.bytes_per_line				dd 0
.last_line				dd 0


