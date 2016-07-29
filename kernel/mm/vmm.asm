
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

page_directory			= 0x9C000
page_tables			= 0x200000

PAGE_PRESENT			= 1
PAGE_WRITEABLE			= 2
PAGE_USER			= 4

; vmm_init:
; Initializes the virtual memory manager and paging subsystem

vmm_init:

	; first construct the page directory
	mov edi, page_directory
	mov ebx, page_tables
	mov ecx, 1024

.dir_loop:
	mov eax, ebx
	or eax, PAGE_PRESENT OR PAGE_WRITEABLE OR PAGE_USER
	stosd

	add ebx, 4096
	loop .dir_loop

	; clear the page tables
	mov edi, page_tables
	mov eax, 0
	mov ecx, 1024*1024
	rep stosd

	; construct the page tables
	mov edi, page_tables
	mov ebx, 0
	mov ecx, 2048				; identity map the lowest 8 MB

.table_loop:
	mov eax, ebx
	or eax, PAGE_PRESENT OR PAGE_USER OR PAGE_WRITEABLE	; only temporarily map the low memory as user
								; because we're testing multitasking...
	stosd

	add ebx, 4096
	loop .table_loop

	mov edi, page_tables
	mov eax, 0
	stosd

	mov eax, VBE_PHYSICAL_BUFFER
	mov ebx, [screen.framebuffer]
	mov ecx, 2048
	mov dl, PAGE_PRESENT OR PAGE_WRITEABLE
	call vmm_map_memory

	; finally enable paging!
	mov eax, page_directory
	mov cr3, eax

	mov eax, cr0
	and eax, 0x1FFFFFFF	; enable caching
	and eax, not 0x10000	; disable write-protection
	or eax, 0x80000000	; enable paging
	mov cr0, eax

	ret

; vmm_map_memory:
; Maps memory into the virtual address space
; In\	EAX = Virtual address
; In\	EBX = Physical address
; In\	ECX = Page count
; In\	DL = Flags
; Out\	Nothing

vmm_map_memory:
	pusha
	mov [.virtual], eax
	mov [.physical], ebx
	mov [.count], ecx
	mov [.flags], dl

	mov edi, [.virtual]
	shr edi, 10
	add edi, page_tables

	mov ebx, [.physical]
	mov ecx, [.count]
	movzx edx, [.flags]

.loop:
	mov eax, ebx
	or eax, edx
	stosd

	add ebx, 4096
	loop .loop

	; next we need to flush the TLB
	mov eax, [.virtual]
	mov ecx, [.count]

.tlb_loop:
	invlpg [eax]
	add eax, 4096
	loop .tlb_loop

	popa
	ret

.virtual			dd 0
.physical			dd 0
.count				dd 0
.flags				db 0

; vmm_unmap_memory:
; Unmaps memory from the virtual address space
; In\	EAX = Virtual address
; In\	ECX = Count
; Out\	Nothing

vmm_unmap_memory:
	mov ebx, 0
	mov dl, 0
	call vmm_map_memory
	ret

; vmm_get_page:
; Gets the physical address and flags of a page
; In\	EAX = Virtual address
; Out\	EAX = 4k-aligned Physical address
; Out\	DL = Page flags

vmm_get_page:
	shr eax, 10
	add eax, page_tables

	mov eax, [eax]
	mov edx, eax
	and eax, 0xFFFFF000
	and edx, 0xFF
	ret

; vmm_alloc_pages:
; Allocates virtual memory
; In\	EAX = Starting address
; In\	ECX = Page count
; Out\	EAX = Address of free virtual memory, unmapped, 0 on error

vmm_alloc_pages:
	mov [.return], eax
	mov [.tmp], eax
	mov [.count], ecx
	mov [.free_pages], 0

.loop:
	mov eax, [.tmp]
	call vmm_get_page
	test dl, 1
	jnz .next

	add [.tmp], 4096
	inc [.free_pages]
	mov ecx, [.count]
	cmp [.free_pages], ecx
	jge .done
	jmp .loop

.next:
	add [.return], 4096
	mov eax, [.return]
	mov [.tmp], eax

	mov [.free_pages], 0
	jmp .loop

.no:
	mov eax, 0
	ret

.done:
	mov eax, [.return]
	ret

.return				dd 0
.tmp				dd 0
.count				dd 0
.free_pages			dd 0

; vmm_alloc:
; Allocates memory
; In\	EAX = Starting address
; In\	ECX = Pages
; In\	DL = Page flags
; Out\	EAX = Memory address, 0 on error

vmm_alloc:
	mov [.count], ecx
	mov [.flags], dl

	; allocate virtual memory
	call vmm_alloc_pages
	cmp eax, 0
	je .no

	mov [.return], eax

	; and physical memory of course
	mov ecx, [.count]
	call pmm_alloc
	cmp eax, 0
	je .no
	mov [.physical], eax

	; now map the memory ;)
	mov eax, [.return]
	mov ebx, [.physical]
	mov ecx, [.count]
	mov dl, [.flags]
	call vmm_map_memory

	; always initialize memory to zero to be safe!
	mov edi, [.return]
	mov eax, 0
	mov ecx, [.count]
	shl ecx, 12
	rep stosb

	mov eax, [.return]
	ret

.no:
	mov eax, 0
	ret

.return				dd 0
.physical			dd 0
.count				dd 0
.flags				db 0

; vmm_free:
; Frees virtual memory
; In\	EAX = Address
; In\	ECX = Pages to free
; Out\	Nothing

vmm_free:
	mov [.address], eax
	mov [.count], ecx

	; free the physical memory first
	call vmm_get_page
	test dl, 1
	jz .quit

	mov ecx, [.count]
	call pmm_free

	mov eax, [.address]
	mov ecx, [.count]
	call vmm_unmap_memory

.quit:
	ret

.address			dd 0
.count				dd 0





