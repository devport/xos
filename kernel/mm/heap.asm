
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

KERNEL_HEAP			= 0xE0000000	; kernel has 64 MB of heap space
USER_HEAP			= 0xE4000000	; user heap starts after the kernel heap and has a maximum of 448 MB

KMALLOC_FLAGS			= PAGE_PRESENT OR PAGE_WRITEABLE
MALLOC_FLAGS			= PAGE_PRESENT OR PAGE_WRITEABLE OR PAGE_USER

; kmalloc:
; Allocates memory in the kernel's heap
; In\	ECX = Bytes to allocate
; Out\	EAX = SSE-aligned pointer to allocated memory
; Note:
; kmalloc() NEVER returns NULL, because it never fails.
; When kmalloc() fails, it fires up a kernel panic.

kmalloc:
	add ecx, 16	; force sse-alignment
	add ecx, 4095
	shr ecx, 12	; to pages
	mov [.pages], ecx

	mov eax, KERNEL_HEAP
	mov ecx, [.pages]
	call vmm_alloc_pages

	cmp eax, USER_HEAP
	jge .no

	mov eax, KERNEL_HEAP
	mov ecx, [.pages]
	mov dl, KMALLOC_FLAGS
	call vmm_alloc
	cmp eax, 0
	je .no
	mov [.return], eax

	mov edi, [.return]
	mov eax, [.pages]
	stosd

	mov eax, [.return]
	add eax, 16
	ret

.no:
	mov eax, 0
	ret

.pages				dd 0
.return				dd 0

; kfree:
; Frees kernel memory
; In\	EAX = Pointer to memory
; Out\	Nothing

kfree:
	mov ecx, [eax-16]
	sub ecx, 16
	call vmm_free
	ret

; malloc:
; Allocates user heap memory
; In\	ECX = Bytes to allocate
; Out\	EAX = SSE-aligned pointer, 0 on error

malloc:
	add ecx, 16	; force sse-alignment
	add ecx, 4095
	shr ecx, 12	; to pages
	mov [.pages], ecx

	mov eax, USER_HEAP
	mov ecx, [.pages]
	mov dl, MALLOC_FLAGS
	call vmm_alloc
	cmp eax, 0
	je .no
	mov [.return], eax

	mov edi, [.return]
	mov eax, [.pages]
	stosd

	mov eax, [.return]
	add eax, 16
	ret

.no:
	mov eax, 0
	ret

.pages				dd 0
.return				dd 0

; free:
; Frees user memory
; In\	EAX = Pointer to memory
; Out\	Nothing

free:
	mov ecx, [eax-16]
	sub ecx, 16
	call vmm_free
	ret





