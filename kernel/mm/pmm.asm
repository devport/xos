
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

total_memory_bytes		dd 0
total_memory_kb			dd 0
total_memory_pages		dd 0
used_memory_pages		dd 0
free_memory_pages		dd 0

pmm_bitmap			= 0x100000

; pmm_init:
; Initializes the physical memory manager

pmm_init:
	movzx eax, [bios_himem]
	shl eax, 6		; mul 64
	movzx ebx, [bios_lomem]
	add eax, ebx
	add eax, 1024
	mov [total_memory_kb], eax

	shl eax, 10
	mov [total_memory_bytes], eax

	mov eax, [total_memory_kb]
	shr eax, 12		; div 4096
	mov [total_memory_pages], eax
	mov [free_memory_pages], eax
	mov [used_memory_pages], 0

	mov esi, .total_msg
	call kprint
	mov eax, [total_memory_kb]
	shr eax, 10
	call int_to_string
	call kprint
	mov esi, .total_msg2
	call kprint

	mov edi, pmm_bitmap
	mov eax, 0
	mov ecx, 0x100000/4
	rep stosd

	; mark the lowest 8 MB as used
	mov eax, 0
	mov ecx, 2048
	call pmm_mark_used

	ret

.total_msg			db "Memory size is ",0
.total_msg2			db " MB.",10,0

; pmm_mark_page_free:
; Marks a physical page as free
; In\	EAX = Address
; Out\	Nothing

pmm_mark_page_free:
	pusha
	shr eax, 12
	add eax, pmm_bitmap
	cmp byte[eax], 0
	je .done

	mov byte[eax], 0
	inc [free_memory_pages]
	dec [used_memory_pages]

.done:
	popa
	ret

; pmm_mark_page_used:
; Marks a physical page as used
; In\	EAX = Address
; Out\	Nothing

pmm_mark_page_used:
	pusha
	shr eax, 12
	add eax, pmm_bitmap
	cmp byte[eax], 1
	je .done

	mov byte[eax], 1
	inc [used_memory_pages]
	dec [free_memory_pages]

.done:
	popa
	ret

; pmm_mark_free:
; Marks a range of physical memory as free
; In\	EAX = Address
; In\	ECX = Count
; Out\	Nothing

pmm_mark_free:
	pusha

.loop:
	call pmm_mark_page_free
	add eax, 4096
	loop .loop

	popa
	ret

; pmm_mark_used:
; Marks a range of physical memory as used
; In\	EAX = Address
; In\	ECX = Count
; Out\	Nothing

pmm_mark_used:
	pusha

.loop:
	call pmm_mark_page_used
	add eax, 4096
	loop .loop

	popa
	ret

; pmm_alloc_page:
; Allocates a single physical page
; In\	Nothing
; Out\	EAX = Address of free page, 0 if not found

pmm_alloc_page:
	mov esi, pmm_bitmap

.loop:
	lodsb
	cmp al, 0		; is page free?
	je .free		; yep -- we've found it

	cmp esi, pmm_bitmap+0x100000
	jge .no

	jmp .loop

.free:
	sub esi, pmm_bitmap
	shl esi, 12
	cmp esi, [total_memory_bytes]
	jge .no

	mov eax, esi
	push eax
	call pmm_mark_page_used
	pop eax
	ret

.no:
	mov eax, 0
	ret

; pmm_is_page_free:
; Checks is a page is free
; In\	EAX = Address
; Out\	DL = 0 if free, 1 if used

pmm_is_page_free:
	cmp eax, [total_memory_bytes]
	jge .used

	mov esi, eax
	shr esi, 12
	add esi, pmm_bitmap
	mov dl, [esi]
	ret

.used:
	mov dl, 1
	ret

; pmm_alloc:
; Allocates contiguous physical memory
; In\	ECX = Page count
; Out\	EAX = Address of memory, 0 on error

pmm_alloc:
	mov [.address], 0
	mov [.count], ecx
	mov [.free_pages], 0

	mov eax, [.address]

.loop:
	call pmm_is_page_free
	cmp dl, 0
	je .free

.used:
	mov [.free_pages], 0
	add [.address], 4096
	mov eax, [.address]
	cmp eax, [total_memory_bytes]
	jge .no

	jmp .loop

.free:
	inc [.free_pages]
	mov ecx, [.count]
	cmp [.free_pages], ecx
	jge .done

	add eax, 4096
	jmp .loop

.done:
	mov eax, [.address]
	mov ecx, [.count]
	call pmm_mark_used

	mov eax, [.address]
	ret

.no:
	mov eax, 0
	ret

.address			dd 0
.count				dd 0
.free_pages			dd 0

; pmm_free:
; Frees physical memory
; In\	EAX = Address
; In\	ECX = Page count
; Out\	Nothing

pmm_free:
	call pmm_mark_free
	ret






