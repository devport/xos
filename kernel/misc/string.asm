
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

hex_values:		db "0123456789ABCDEF"

; strlen:
; Calculates string length
; In\	ESI = String
; Out\	EAX = String size

strlen:
	push esi

	xor ecx, ecx

.loop:
	lodsb
	cmp al, 0
	je .done
	inc ecx
	jmp .loop

.done:
	mov eax, ecx
	pop esi
	ret

; hex_nibble_to_string:
; Converts a hex nibble to string
; In\	AL = Low nibble to convert
; Out\	ESI = String

hex_nibble_to_string:
	and eax, 0x0F
	add eax, hex_values
	mov al, [eax]
	mov [.string], al

	mov esi, .string
	ret

.string:		times 2 db 0

; hex_byte_to_string:
; Converts a hex byte to string
; In\	AL = Byte
; Out\	ESI = String

hex_byte_to_string:
	mov [.byte], al

	call hex_nibble_to_string
	mov edi, .string+1
	movsb

	mov al, [.byte]
	shr al, 4
	call hex_nibble_to_string
	mov edi, .string
	movsb

	mov esi, .string
	ret

.byte			db 0
.string:		times 3 db 0

; hex_word_to_string:
; Converts a hex word to a string
; In\	AX = Word
; Out\	ESI = String

hex_word_to_string:
	mov [.word], ax

	call hex_byte_to_string
	mov edi, .string+2
	movsw

	mov ax, [.word]
	shr ax, 8
	call hex_byte_to_string
	mov edi, .string
	movsw

	mov esi, .string
	ret

.word			dw 0
.string:		times 5 db 0

; hex_dword_to_string:
; Converts a hex dword to a string
; In\	EAX = DWORD
; Out\	ESI = String

hex_dword_to_string:
	mov [.dword], eax

	call hex_word_to_string
	mov edi, .string+4
	movsd

	mov eax, [.dword]
	shr eax, 16
	call hex_word_to_string
	mov edi, .string
	movsd

	mov esi, .string
	ret

.dword			dd 0
.string:		times 9 db 0

; hex_qword_to_string:
; Converts a hex qword to a string
; In\	EDX:EAX = QWORD
; Out\	ESI = String

hex_qword_to_string:
	push edx
	call hex_dword_to_string
	mov edi, .string+8
	mov ecx, 8
	rep movsb

	pop eax
	call hex_dword_to_string
	mov edi, .string
	mov ecx, 8
	rep movsb

	mov esi, .string
	ret

.qword			dd 0
.string:		times 17 db 0

; int_to_string:
; Converts an unsigned integer to a string
; In\	EAX = Integer
; Out\	ESI = ASCIIZ string

int_to_string:
	push eax
	mov [.counter], 10

	mov edi, .string
	mov ecx, 10
	mov eax, 0
	rep stosb

	mov esi, .string
	add esi, 9
	pop eax

.loop:
	cmp eax, 0
	je .done2
	mov ebx, 10
	mov edx, 0
	div ebx

	add dl, 48
	mov byte[esi], dl
	dec esi

	sub byte[.counter], 1
	cmp byte[.counter], 0
	je .done
	jmp .loop

.done:
	mov esi, .string
	ret

.done2:
	cmp byte[.counter], 10
	je .zero
	mov esi, .string

.find_string_loop:
	lodsb
	cmp al, 0
	jne .found_string
	jmp .find_string_loop

.found_string:
	dec esi
	ret

.zero:
	mov edi, .string
	mov al, '0'
	stosb
	mov al, 0
	stosb
	mov esi, .string

	ret

.string:		times 11 db 0
.counter		db 0

; trim_string:
; Trims a string from forward and backward spaces
; In\	ESI = String
; Out\	ESI = Modified string

trim_string:
	push esi

.trim_spaces:
	mov ax, [esi]

	cmp ax, 0x2020
	je .remove_space

	cmp al, 0
	je .removed_all_spaces

	add esi, 2
	jmp .trim_spaces

.remove_space:
	mov word[esi], 0x0000
	add esi, 2
	jmp .trim_spaces

.removed_all_spaces:
	pop esi

.search_for_start:
	cmp byte[esi], 0x00
	je .forward

	mov [.string], esi

	mov esi, [.string]
	call strlen
	add esi, eax
	dec esi
	cmp byte[esi], 0x20
	je .remove_last_space

	mov esi, [.string]
	ret

.forward:
	inc esi
	jmp .search_for_start

.remove_last_space:
	mov byte[esi], 0x00
	mov esi, [.string]
	ret

.string				dd 0

; swap_string_order:
; Swaps the byte-order of a string (needed for ATA really.. stupid)
; In\	ESI = String
; Out\	String modified

swap_string_order:
	pusha

.loop:
	mov ax, [esi]

	cmp al, 0
	je .done
	cmp ah, 0
	je .done

	xchg al, ah
	mov [esi], ax
	add esi, 2
	jmp .loop

.done:
	popa
	ret




