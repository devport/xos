
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; mm_init:
; Initializes the memory manager

mm_init:
	call pmm_init
	call vmm_init

	; set the framebuffer to write-combine
	;mov eax, [screen.framebuffer]
	;mov ecx, 0x800000
	;mov dl, MTRR_WRITE_COMBINE
	;call mtrr_set_range

	; allocate a stack for the kernel API and usermode IRQs/exceptions
	mov ecx, 32768		; 32kb should be much more than enough
	call kmalloc
	add eax, 32768
	mov [tss.esp0], eax
	;mov [tss.esp], eax

	; load the tss
	mov eax, 0x3B
	ltr ax
	nop

	; allocate memory for the VESA framebuffer
	mov ecx, 2048		; 8 MB
	call pmm_alloc
	cmp eax, 0
	je .no_mem_fb

	mov ebx, eax
	mov eax, VBE_BACK_BUFFER
	mov ecx, 2048
	mov dl, PAGE_PRESENT OR PAGE_WRITEABLE
	call vmm_map_memory

	ret

.no_mem_fb:
	mov esi, .no_mem_msg
	jmp early_boot_error

.no_mem_msg			db "Not enough memory to initialize a VBE back buffer.",0

; memxchg:
; Exchanges memory
; In\	ESI = Memory location #1
; In\	EDI = Memory location #2
; In\	ECX = Bytes to exchange
; Out\	Nothing

memxchg:
	pusha

	cmp ecx, 4
	jl .just_bytes

	push ecx
	shr ecx, 2

.loop:
	mov eax, [esi]
	mov [.tmp], eax
	mov eax, [edi]
	mov [esi], eax
	mov eax, [.tmp]
	mov [edi], eax

	add esi, 4
	add edi, 4
	loop .loop

	pop ecx
	and ecx, 3
	cmp ecx, 0
	je .done

.just_bytes:
	mov al, [esi]
	mov byte[.tmp], al
	mov al, [edi]
	mov [esi], al
	mov al, byte[.tmp]
	mov [edi], al

	inc esi
	inc edi
	loop .loop

.done:
	popa
	ret

.tmp				dd 0

; memcpy:
; Fast SSE memcpy
; In\	ESI = Source
; In\	EDI = Destination
; In\	ECX = Byte count
; Out\	Nothing

memcpy:
	test esi, 0xF
	jnz memcpy_u

	test edi, 0xF
	jnz memcpy_u

	cmp ecx, 128
	jl .just_bytes

	push ecx
	shr ecx, 7	; div 128

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

	pop ecx

.just_bytes:
	push ecx

	and ecx, 0x7F
	shr ecx, 2	; div 4
	rep movsd

	pop ecx
	and ecx, 3
	rep movsb

	ret

memcpy_u:
	cmp ecx, 128
	jl .just_bytes

	push ecx
	shr ecx, 7	; div 128

.loop:
	movdqu xmm0, [esi]
	movdqu xmm1, [esi+0x10]
	movdqu xmm2, [esi+0x20]
	movdqu xmm3, [esi+0x30]
	movdqu xmm4, [esi+0x40]
	movdqu xmm5, [esi+0x50]
	movdqu xmm6, [esi+0x60]
	movdqu xmm7, [esi+0x70]

	movdqu [edi], xmm0
	movdqu [edi+0x10], xmm1
	movdqu [edi+0x20], xmm2
	movdqu [edi+0x30], xmm3
	movdqu [edi+0x40], xmm4
	movdqu [edi+0x50], xmm5
	movdqu [edi+0x60], xmm6
	movdqu [edi+0x70], xmm7

	add esi, 128
	add edi, 128
	loop .loop

	pop ecx

.just_bytes:
	push ecx

	and ecx, 0x7F
	shr ecx, 2	; div 4
	rep movsd

	pop ecx
	and ecx, 3
	rep movsb

	ret


