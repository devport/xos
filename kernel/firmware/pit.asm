
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

TIMER_FREQUENCY			= 1000
MAXIMUM_TASK_TIME		= TIMER_FREQUENCY / 10

timer_ticks			dd 0
task_time			dd 0

; pit_init:
; Initialize the PIT

pit_init:
	mov esi, .msg
	call kprint

	; install IRQ handler
	mov al, IRQ_BASE+0x00	; irq0
	mov ebp, pit_irq
	call install_isr

	; set frequency and mode
	mov al, 0x36
	out 0x43, al
	call iowait

	mov eax, 1193182/TIMER_FREQUENCY
	out 0x40, al
	call iowait

	mov al, ah
	out 0x40, al
	call iowait

	; unmask IRQ
	mov al, 0
	call pic_unmask

	ret

.msg			db "Setting PIT frequency...",10,0

; pit_irq:
; PIT IRQ Handler

pit_irq:
	push eax

	inc [timer_ticks]

	cmp [current_task], 0
	je .idle

.non_idle:
	inc [nonidle_time]
	jmp .done

.idle:
	inc [idle_time]

.done:
	mov al, 0x20
	out 0x20, al

	pop eax
	iret




