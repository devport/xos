
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; MTRR registers...
IA32_MTRRCAP			= 0xFE
IA32_MTRR_DEF_TYPE		= 0x2FF
IA32_MTRR_PHYSBASE		= 0x200
IA32_MTRR_PHYSMASK		= 0x201
IA32_MTRR_FIX64K_00000		= 0x250
IA32_MTRR_FIX16K_80000		= 0x258
IA32_MTRR_FIX16K_A0000		= 0x259
IA32_MTRR_FIX4K_C0000		= 0x268
IA32_MTRR_FIX4K_C8000		= 0x269
IA32_MTRR_FIX4K_D0000		= 0x26A
IA32_MTRR_FIX4K_D8000		= 0x26B
IA32_MTRR_FIX4K_E0000		= 0x26C
IA32_MTRR_FIX4K_E8000		= 0x26D
IA32_MTRR_FIX4K_F0000		= 0x26E
IA32_MTRR_FIX4K_F8000		= 0x26F

; MTRR memory types
MTRR_UNCACHEABLE		= 0
MTRR_WRITE_COMBINE		= 1
MTRR_WRITE_THROUGH		= 4
MTRR_WRITE_PROTECTED		= 5
MTRR_WRITEBACK			= 6

mtrr_mask			dq 0xFFFFFFFFF		; default 36-bit mask
mtrr_ranges			db 0

; mtrr_disable:
; Disables MTRR

mtrr_disable:
	mov ecx, IA32_MTRR_DEF_TYPE
	rdmsr
	and eax, 0xFFFFF7FF
	wrmsr
	ret

; mtrr_enable:
; Enables MTRR

mtrr_enable:
	mov ecx, IA32_MTRR_DEF_TYPE
	rdmsr
	or eax, 0x800
	wrmsr
	ret

; mtrr_find_range:
; Finds an MTRR range
; In\	Nothing
; Out\	ECX = MSR of PHYSBASE, -1 on error

mtrr_find_range:
	mov [.current], 0

.loop:
	movzx ecx, [mtrr_ranges]
	cmp [.current], ecx
	jg .no

	mov ecx, [.current]
	shl ecx, 1
	add ecx, IA32_MTRR_PHYSMASK
	rdmsr

	test eax, 0x800		; is the range used?
	jz .found		; nope -- return it

	inc [.current]
	jmp .loop

.found:
	dec ecx
	ret

.no:
	mov eax, -1
	ret

.current		dd 0

; mtrr_set_range:
; Sets an MTRR range
; In\	EAX = Physical address, 4k aligned
; In\	ECX = Bytes to cache, multiple of 4k
; In\	DL = Cache type
; Out\	EAX = 0 on success, 1 if MTRR not supported, 2 if no free MTRR ranges available, 3 if caching type not supported

mtrr_set_range:
	mov [.phys], eax
	mov [.bytes], ecx
	mov [.type], dl

	cmp [.type], 2
	je .no_type
	cmp [.type], 3
	je .no_type
	cmp [.type], MTRR_WRITEBACK
	jg .no_type

	mov esi, .msg
	call kprint
	mov eax, [.phys]
	call hex_dword_to_string
	call kprint
	mov esi, .msg2
	call kprint
	mov eax, [.bytes]
	call hex_dword_to_string
	call kprint
	mov esi, .msg3
	call kprint
	movzx eax, [.type]
	call int_to_string
	call kprint
	mov esi, .msg4
	call kprint

	; check MTRR support
	mov eax, 1
	cpuid
	test edx, 0x1000
	jz .no_mtrr

	; disable MTRR
	call mtrr_disable

	; save CR4
	mov eax, cr4
	mov [kernel_cr4], eax

	; disable caching
	wbinvd
	mov eax, cr0
	or eax, 0x60000000
	mov cr0, eax

	; number of MTRR ranges
	mov ecx, IA32_MTRRCAP
	rdmsr
	mov [mtrr_ranges], al

	cmp [mtrr_ranges], 0
	je .no_ranges

	call mtrr_find_range
	cmp ecx, -1
	je .no_ranges
	mov [.mtrr], ecx

	; set the base, cache type and mask
	pushfd
	cli

	mov ecx, [.mtrr]
	mov edx, 0
	mov eax, [.phys]
	and eax, 0xFFFFF000
	or al, [.type]
	wrmsr

	inc ecx
	mov edx, dword[mtrr_mask+4]
	mov eax, [.bytes]
	and eax, 0xFFFFF000
	not eax
	and eax, 0xFFFFF000
	or eax, 0x800
	wrmsr

	nop
	nop

	; enable MTRR
	call mtrr_enable

	; enable caching
	wbinvd
	mov eax, cr0
	and eax, 0x9FFFFFFF
	mov cr0, eax

	; reload CR4
	mov eax, [kernel_cr4]
	mov cr4, eax

	popfd
	mov eax, 0
	ret

.no_mtrr:
	mov esi, .err_msg
	call kprint
	mov esi, .no_mtrr_msg
	call kprint
	mov eax, 1
	ret

.no_ranges:
	mov esi, .err_msg
	call kprint
	mov esi, .no_ranges_msg
	call kprint
	mov eax, 2
	ret

.no_type:
	mov esi, .err_msg
	call kprint
	mov esi, .no_type_msg
	call kprint
	mov eax, 3
	ret

.phys			dd 0
.bytes			dd 0
.type			db 0
.mtrr			dd 0
.msg			db "Setting MTRR (base 0x",0
.msg2			db ", size 0x",0
.msg3			db ", caching type ",0
.msg4			db ")",10,0
.err_msg		db "There a problem with MTRR configuration. Details: ",0
.no_mtrr_msg		db "MTRR not supported.",10,0
.no_ranges_msg		db "no free MTRR ranges.",10,0
.no_type_msg		db "unsupported MTRR type.",10,0





