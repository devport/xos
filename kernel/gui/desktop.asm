
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

main_menu		db "OFF",0

; desktop_redraw:
; Redraws the desktop

desktop_redraw:
	; start with the background
	mov ebx, [wm_color]
	call clear_screen

	mov ax, 0
	mov bx, 0
	mov esi, [screen.width]
	mov di, 32
	mov edx, [window_border]
	call fill_rect

	mov ax, 0
	mov bx, 30
	mov esi, [screen.width]
	mov di, 2
	mov edx, [window_header]
	call fill_rect

	mov ax, 0
	mov bx, 0
	mov esi, 40
	mov edi, 32
	mov edx, 0x00B000
	call fill_rect

	mov ecx, 0x000000
	call set_text_color

	mov cx, 8
	mov dx, 8
	mov esi, main_menu
	call print_string_transparent

	mov ecx, 0xFFFFFF
	call set_text_color

	mov cx, 7
	mov dx, 7
	mov esi, main_menu
	call print_string_transparent

	ret

; desktop_event:
; Desktop event handler

desktop_event:
	mov [active_window], -1

	cmp [mouse_x], 40
	jl main_menu_handler

	ret

; main_menu_handler:
; Main Menu Event Handler

main_menu_handler:
	cli

	; destroy all windows
	call wm_kill_all

	; create one window in the middle of the screen
	mov eax, [screen.width]
	mov ebx, [screen.height]
	shr eax, 1
	shr ebx, 1
	sub eax, 300/2
	sub ebx, 160/2

	mov esi, 330
	mov edi, 160
	mov dx, 0
	mov ecx, .title
	call wm_create_window

	cmp eax, -1
	je .just_shutdown

	; display "It's now safe to power off your PC." in case the shutdown fails
	mov esi, .msg
	mov cx, 24
	mov dx, 32
	mov ebx, 0x000000
	call wm_draw_text

.just_shutdown:
	; enter ACPI sleep state S5
	mov esp, stack16+2048
	mov al, 5
	call acpi_sleep

	; if it fails, we'll be here
	mov al, 0x20
	out 0xA0, al
	out 0x20, al

	; just hang

.hang:
	sti
	hlt
	jmp .hang

.title			db "System",0
.msg			db "It's now safe to power off your PC.",0


