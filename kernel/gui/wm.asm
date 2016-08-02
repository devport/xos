
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

;
; struct window_handle {
; u16 flags;			// 0x00
; u16 event;			// 0x02
; u16 width;			// 0x04
; u16 height;			// 0x06
; u16 x;			// 0x08
; u16 y;			// 0x0A
; u32 framebuffer;		// 0x0C
; u32 reserved;			// 0x10
; u32 pid;			// 0x14
; u16 max_x;			// 0x18
; u16 max_y;			// 0x1A
; char title[65];		// 0x1C
; u8 padding[35];		// 0x5D
; };
;
;
; sizeof(window_handle) = 0x80;
;

; Structure of window handle
WINDOW_FLAGS			= 0x00
WINDOW_EVENT			= 0x02
WINDOW_WIDTH			= 0x04
WINDOW_HEIGHT			= 0x06
WINDOW_X			= 0x08
WINDOW_Y			= 0x0A
WINDOW_FRAMEBUFFER		= 0x0C
WINDOW_CONTROLS			= 0x10
WINDOW_PID			= 0x14
WINDOW_MAX_X			= 0x18
WINDOW_MAX_Y			= 0x1A
WINDOW_TITLE			= 0x1C
WINDOW_HANDLE_SIZE		= 0x80

; Window Flags
WM_PRESENT			= 0x0001
WM_HIDDEN			= 0x0002
WM_ALPHA			= 0x0004
WM_THIN_BORDER			= 0x0008
WM_NO_BORDER			= 0x0010

; Window Events
WM_LEFT_CLICK			= 0x0001
WM_RIGHT_CLICK			= 0x0002
WM_KEYPRESS			= 0x0004
WM_BUTTON			= 0x0008

MAXIMUM_WINDOWS			= 16

open_windows			dd 0
active_window			dd -1
window_handles			dd 0
wm_background			dd 0
wm_running			db 0

; Window Theme!
; TO-DO: Set these values from a theme file from the disk (i.e. make the gui costomizable)
align 16
wm_color			dd 0x303030
;window_header			dd 0xE8A200
window_header			dd 0x00A2E8
window_inactive_header		dd 0x222222
window_inactive_title		dd 0xFFFFFF
window_border			dd 0x444444
window_title			dd 0xFFFFFF
window_close_color		dd 0xC02020
window_background		dd 0xD8D8D8
;window_opacity			dd 0		; when I implement alpha blending i'll have this ;)

; wm_init:
; Initializes the window manager

wm_init:
	mov esi, .msg
	call kprint

	cli		; sensitive area of code!

	; allocate memory for window handles
	mov ecx, WINDOW_HANDLE_SIZE*MAXIMUM_WINDOWS
	call kmalloc
	mov [window_handles], eax

	; place mouse in middle of screen
	mov eax, [screen.width]
	mov ebx, [screen.height]
	shr eax, 1
	shr ebx, 1
	mov [mouse_x], eax
	mov [mouse_y], ebx
	call show_mouse

	mov [wm_running], 1
	sti
	call wm_redraw
	ret

.msg			db "Start windowing system...",10,0
.title			db "Test Window",0

; wm_find_handle:
; Finds a free window handle
; In\	Nothing
; Out\	EAX = Window handle, -1 on error

wm_find_handle:
	cmp [open_windows], MAXIMUM_WINDOWS
	jge .no

	mov [.handle], 0

.loop:
	mov eax, [.handle]
	;mov ebx, WINDOW_HANDLE_SIZE
	;mul ebx
	shl eax, 7
	add eax, [window_handles]

	test word[eax], WM_PRESENT
	jz .found

	inc [.handle]
	cmp [.handle], MAXIMUM_WINDOWS
	jge .no
	jmp .loop

.found:
	mov edi, eax
	xor al, al
	mov ecx, WINDOW_HANDLE_SIZE
	rep stosb

	mov eax, [.handle]
	ret

.no:
	mov eax, -1
	ret

.handle			dd 0

; wm_get_window:
; Returns information of a window handle
; In\	EAX = Window handle
; Out\	EFLAGS.CF = 0 if present
; Out\	AX/BX = X/Y pos
; Out\	SI/DI = Width/Height
; Out\	DX = Flags
; Out\	ECX = Framebuffer
; Out\	EBP = Title text

wm_get_window:
	cmp eax, MAXIMUM_WINDOWS
	jge .no

	;mov ebx, WINDOW_HANDLE_SIZE
	;mul ebx
	shl eax, 7
	add eax, [window_handles]
	test word[eax], WM_PRESENT
	jz .no

	mov bx, [eax+WINDOW_Y]
	mov si, [eax+WINDOW_WIDTH]
	mov di, [eax+WINDOW_HEIGHT]
	mov dx, [eax]
	mov ecx, [eax+WINDOW_FRAMEBUFFER]
	mov ebp, eax
	add ebp, WINDOW_TITLE
	mov ax, [eax+WINDOW_X]

	clc
	ret

.no:
	stc
	ret

; wm_make_handle:
; Creates a window handle
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	DX = Flags
; In\	ECX = Window handle
; In\	EBP = Framebuffer address
; Out\	Nothing

wm_make_handle:
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.flags], dx
	mov [.framebuffer], ebp

	mov eax, ecx		; eax = window handle
	;mov ebx, WINDOW_HANDLE_SIZE
	;mul ebx
	shl eax, 7
	add eax, [window_handles]

	mov dx, [.flags]
	or dx, WM_PRESENT
	mov [eax], dx

	mov dx, [.x]
	mov [eax+WINDOW_X], dx

	mov dx, [.y]
	mov [eax+WINDOW_Y], dx

	mov dx, [.width]
	mov [eax+WINDOW_WIDTH], dx

	mov dx, [.height]
	mov [eax+WINDOW_HEIGHT], dx

	mov edx, [screen.width]
	sub dx, [.width]
	;sub dx, 8
	mov [eax+WINDOW_MAX_X], dx

	mov edx, [screen.height]
	sub dx, [.height]
	;sub dx, 32
	sub dx, 24
	mov [eax+WINDOW_MAX_Y], dx

	mov edx, [.framebuffer]
	mov [eax+WINDOW_FRAMEBUFFER], edx

	ret

.x			dw 0
.y			dw 0
.width			dw 0
.height			dw 0
.flags			dw 0
.framebuffer		dd 0

; wm_create_window:
; Creates a window
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	DX = Flags
; In\	ECX = Title text
; Out\	EAX = Window handle, -1 on error

wm_create_window:
	cmp [open_windows], MAXIMUM_WINDOWS
	jge .no

	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.flags], dx
	mov [.title], ecx

	; find a free window handle
	call wm_find_handle
	cmp eax, -1
	je .no
	mov [.handle], eax

	; allocate a framebuffer
	movzx eax, [.width]
	movzx ebx, [.height]
	mul ebx
	shl eax, 2		; mul 4
	mov ecx, eax
	call malloc

	cmp eax, 0
	je .no

	mov [.framebuffer], eax

	; clear the framebuffer
	movzx eax, [.width]
	movzx ebx, [.height]
	mul ebx
	mov ecx, eax
	mov edi, [.framebuffer]
	mov eax, [window_background]
	rep stosd

	; create the window handle
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	mov dx, [.flags]
	or dx, WM_PRESENT
	mov ecx, [.handle]
	mov ebp, [.framebuffer]
	call wm_make_handle

	cmp [.title], 0
	je .done

	mov eax, [.handle]
	;mov ebx, WINDOW_HANDLE_SIZE
	;mul ebx
	shl eax, 7
	add eax, [window_handles]
	add eax, WINDOW_TITLE
	mov edi, eax
	mov esi, [.title]
	mov ecx, 64
	rep movsb

.done:
	mov eax, [.handle]
	mov [active_window], eax	; by default, when a new window is created, the focus goes to it
	inc [open_windows]
	call wm_redraw

	mov eax, [.handle]	; return the window handle to the application
	ret

.no:
	mov eax, -1
	ret

.x			dw 0
.y			dw 0
.width			dw 0
.height			dw 0
.flags			dw 0
.handle			dd 0
.framebuffer		dd 0
.title			dd 0

; wm_detect_window:
; Detects which window the mouse is on
; In\	Nothing
; Out\	EAX = Window handle, -1 on error

wm_detect_window:
	cmp [open_windows], 0
	je .no

	mov [.handle], MAXIMUM_WINDOWS-1

.loop:
	cmp [.handle], -1
	je .no

	mov eax, [.handle]
	call wm_get_window
	jc .next

	mov [.x], ax
	mov [.y], bx
	add si, ax
	add di, bx
	add di, 24
	mov [.max_x], si
	mov [.max_y], di

	mov eax, [mouse_x]
	mov ebx, [mouse_y]

	cmp ax, [.x]
	jl .next
	cmp ax, [.max_x]
	jg .next

	cmp bx, [.y]
	jl .next
	cmp bx, [.max_y]
	jg .next

	; return the window handle
	mov eax, [.handle]
	ret

.next:
	dec [.handle]
	jmp .loop

.no:
	mov eax, -1
	ret

.handle			dd 0
.x			dw 0
.y			dw 0
.max_x			dw 0
.max_y			dw 0

; wm_is_mouse_on_window:
; Checks if the mouse is on the surface of a window
; In\	EAX = Window handle
; Out\	EAX = 1 if mouse is on surface of window

wm_is_mouse_on_window:
	call wm_get_window
	jc .no

	mov [.x], ax
	mov [.y], bx
	add si, ax
	add di, bx
	add di, 24
	mov [.max_x], si
	mov [.max_y], di

	mov eax, [mouse_x]
	mov ebx, [mouse_y]

	cmp ax, [.x]
	jl .no
	cmp ax, [.max_x]
	jg .no

	cmp bx, [.y]
	jl .no
	cmp bx, [.max_y]
	jg .no

	mov eax, 1
	ret

.no:
	xor eax, eax	; mov eax, 0
	ret

.x			dw 0
.y			dw 0
.max_x			dw 0
.max_y			dw 0

; wm_redraw:
; Redraws all windows

wm_redraw:
	; lock the screen to improve performance!
	call use_back_buffer
	call lock_screen

	call desktop_redraw

	; now move on to the windows
	xor eax, eax
	mov [.handle], eax
	cmp [open_windows], eax
	je .done

	;mov ebx, 0
	mov ecx, [window_inactive_title]
	call set_text_color

.loop:
	cmp [.handle], MAXIMUM_WINDOWS
	jge .do_active_window

	mov eax, [active_window]
	cmp [.handle], eax
	je .next

	mov eax, [.handle]
	call wm_get_window
	jc .next
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.framebuffer], ecx
	mov [.title], ebp

	; draw the window border
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	;mov di, [.height]
	;add si, 8
	;add di, 32
	mov di, 24
	mov edx, [window_border]
	call fill_rect

	;mov ax, [.x]
	;mov bx, [.y]
	;mov si, [.width]
	;mov di, 2
	;mov edx, [window_inactive_header]
	;call fill_rect

	; the close button
	mov ax, [.x]
	mov bx, [.y]
	add ax, 4
	add bx, 4
	mov si, 16
	mov di, 16
	mov edx, [window_close_color]
	call fill_rect

	; the window title
	mov esi, [.title]
	mov cx, [.x]
	mov dx, [.y]
	add cx, 4+16+4
	add dx, 4
	call print_string_transparent

	; the window frame buffer
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	;add ax, 4
	add bx, 24
	mov edx, [.framebuffer]
	call blit_buffer_no_transparent

.next:
	inc [.handle]
	jmp .loop

.do_active_window:
	cmp [active_window], -1
	je .done

	mov ecx, [window_title]
	call set_text_color

	mov eax, [active_window]
	call wm_get_window
	jc .done
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.framebuffer], ecx
	mov [.title], ebp

	; draw the window border
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	;mov di, [.height]
	;add si, 8
	;add di, 32
	mov di, 24
	mov edx, [window_border]
	call fill_rect

	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, 2
	mov edx, [window_header]
	call fill_rect

	; the close button
	mov ax, [.x]
	mov bx, [.y]
	add ax, 4
	add bx, 4
	mov si, 16
	mov di, 16
	mov edx, [window_close_color]
	call fill_rect

	; the window title
	mov esi, [.title]
	mov cx, [.x]
	mov dx, [.y]
	add cx, 4+16+4
	add dx, 4
	call print_string_transparent

	; the window frame buffer
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	;add ax, 4
	add bx, 24
	mov edx, [.framebuffer]
	call blit_buffer_no_transparent

.done:
	call redraw_mouse	; this takes care of all the dirty work before actually drawing the cursor ;)
	ret

.handle			dd 0
.x			dw 0
.y			dw 0
.width			dw 0
.height			dw 0
.framebuffer		dd 0
.title			dd 0

; wm_event:
; WM Event Handler

wm_event:
	cli		; sensitive area!

	test [wm_running], 1
	jz .no_wm

	;test [mouse_data], MOUSE_LEFT_BTN	; left click event
	;jz .done

	; now we know the user has his finger on the left button
	; is he clicking or dragging?
	test [mouse_old_data], MOUSE_LEFT_BTN
	jnz .drag

.click:
	; now we know the user just clicked on something
	; if he clicked on the active window, send the window a click event
	; if not, then give the window focus and send it a click event too
	; if the user did not click on a window, ignore the event
	mov eax, [active_window]
	cmp eax, MAXIMUM_WINDOWS
	jge .set_focus

	call wm_is_mouse_on_window
	or eax, eax
	jz .set_focus

	; send the window a click event ONLY if the mouse is not on the title bar
	; otherwise we page fault in usermode! ;)
	mov eax, [active_window]
	shl eax, 7
	add eax, [window_handles]

	mov ecx, [mouse_y]
	mov dx, [eax+WINDOW_Y]
	add dx, 24
	cmp cx, dx
	jl .check_taskbar

	or word[eax+WINDOW_EVENT], WM_LEFT_CLICK

	jmp .done

.set_focus:
	call wm_detect_window
	mov [active_window], eax
	cmp eax, -1
	je .check_taskbar
	jmp .click
	;jmp .done

.check_taskbar:
	cmp [mouse_y], 32
	jl .desktop_event
	jmp .done

.desktop_event:
	call desktop_event
	jmp .done

.drag:
	; if the user dragged something --
	; -- we'll need to know if a window has been dragged --
	; -- because we'll need to move the window to follow the mouse ;)
	cmp [active_window], MAXIMUM_WINDOWS
	jge .done

	mov esi, [active_window]
	shl esi, 7	; mul 128
	add esi, [window_handles]

	; make sure the mouse is actually on the window title bar
	mov ecx, [mouse_y]
	mov dx, [esi+WINDOW_Y]
	cmp cx, dx
	jl .done

	add dx, 24
	cmp cx, dx
	jg .click

	mov ecx, [mouse_old_x]
	mov edx, [mouse_old_y]
	mov eax, [mouse_x]
	mov ebx, [mouse_y]

.do_x:
	sub ax, cx
	js .x_negative

	add [esi+WINDOW_X], ax
	mov ax, [esi+WINDOW_MAX_X]
	cmp [esi+WINDOW_X], ax
	jg .x_max

	jmp .do_y

.x_max:
	mov ax, [esi+WINDOW_MAX_X]
	mov [esi+WINDOW_X], ax
	jmp .do_y

.x_negative:
	not ax
	inc ax
	sub [esi+WINDOW_X], ax
	js .x_zero
	jmp .do_y

.x_zero:
	mov word[esi+WINDOW_X], 0

.do_y:
	sub bx, dx
	js .y_negative

	add [esi+WINDOW_Y], bx
	mov bx, [esi+WINDOW_MAX_Y]
	cmp [esi+WINDOW_Y], bx
	jg .y_max
	jmp .done

.y_max:
	mov bx, [esi+WINDOW_MAX_Y]
	mov [esi+WINDOW_Y], bx
	jmp .done

.y_negative:
	not bx
	inc bx
	sub [esi+WINDOW_Y], bx
	js .y_zero

	jmp .done

.y_zero:
	mov word[esi+WINDOW_Y], 0

.done:
	call wm_redraw
	ret

.no_wm:
	call redraw_mouse
	ret

.handle			dd 0

; wm_read_event:
; Reads the WM event
; In\	EAX = Window handle
; Out\	AX = Bitfield of WM event data; I'll document this somewhere

wm_read_event:
	cmp eax, MAXIMUM_WINDOWS
	jge .no

	shl eax, 7
	add eax, [window_handles]
	test word[eax], WM_PRESENT	; is the window present?
	jz .no

	mov edi, eax
	mov ax, [edi+WINDOW_EVENT]	; return the event data
	mov word[edi+WINDOW_EVENT], 0
	and eax, 0xFFFF			; because the high bits of eax will contain memory locations in the kernel heap
					; although the kernel heap is not accessible to ring 3, this probably doesn't hurt
	ret

.no:
	xor ax, ax
	ret

; wm_kill:
; Kills a window
; In\	EAX = Window handle
; Out\	Nothing

wm_kill:
	cli
	mov [active_window], -1

	shl eax, 7
	add eax, [window_handles]
	test word[eax], WM_PRESENT
	jz .no

	push eax
	mov eax, [eax+WINDOW_FRAMEBUFFER]
	call free		; free the framebuffer memory

	pop edi
	mov eax, 0
	mov ecx, WINDOW_HANDLE_SIZE
	rep stosb

	dec [open_windows]

.no:
	call wm_redraw
	ret

; wm_kill_all:
; Kills all windows

wm_kill_all:
	mov [.handle], 0

.loop:
	cmp [.handle], MAXIMUM_WINDOWS
	jge .done

	mov eax, [.handle]
	call wm_kill

	inc [.handle]
	jmp .loop

.done:
	ret

.handle		dd 0


