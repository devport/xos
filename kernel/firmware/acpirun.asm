
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; AML Opcodes
AML_OPCODE_ZERO			= 0x00
AML_OPCODE_ONE			= 0x01
AML_OPCODE_ALIAS		= 0x06
AML_OPCODE_NAME			= 0x08
AML_OPCODE_BYTEPREFIX		= 0x0A
AML_OPCODE_WORDPREFIX		= 0x0B
AML_OPCODE_DWORDPREFIX		= 0x0C
AML_OPCODE_STRINGPREFIX		= 0x0D
AML_OPCODE_QWORDPREFIX		= 0x0E
AML_OPCODE_PACKAGE		= 0x12
AML_OPCODE_RETURN		= 0xA4
AML_OPCODE_ONES			= 0xFF

; ACPI Control Block Fields
ACPI_CONTROL_ENABLED		= 0x0001
ACPI_CONTROL_SLEEP		= 0x2000

; acpi_ssdt_find:
; Finds an object within the ACPI SSDT
; In\	ESI = Object identifier followed by AML_OPCODE_ZERO
; Out\	EAX = Pointer to object within ACPI SSDT, -1 on error

acpi_ssdt_find:
	mov [.object], esi
	call strlen
	mov [.object_size], ecx

	; get pointer to ssdt
	mov eax, "SSDT"
	call acpi_find_table
	cmp eax, -1
	je .no

	mov esi, eax
	mov edi, esi
	add edi, [esi+4]		; size of ssdt
	mov [.end_ssdt], edi
	add esi, ACPI_SDT_SIZE

.find_loop:
	cmp esi, [.end_ssdt]
	jge .no

	push esi
	mov edi, [.object]
	mov ecx, [.object_size]
	rep cmpsb
	je .found

	pop esi
	inc esi
	jmp .find_loop

.found:
	pop eax
	ret

.no:
	mov eax, -1
	ret

.object			dd 0
.object_size		dd 0
.end_ssdt		dd 0

; acpi_dsdt_find:
; Finds an object within the ACPI DSDT
; In\	ESI = Object identifier followed by AML_OPCODE_ZERO
; Out\	EAX = Pointer to object within ACPI DSDT, -1 on error

acpi_dsdt_find:
	mov [.object], esi
	call strlen
	mov [.object_size], ecx

	; get pointer to dsdt
	mov esi, [acpi_fadt.dsdt]
	mov edi, esi
	add edi, [esi+4]		; size of dsdt
	mov [.end_dsdt], edi

	mov esi, [acpi_fadt.dsdt]
	add esi, ACPI_SDT_SIZE

.find_loop:
	cmp esi, [.end_dsdt]
	jge .no

	push esi
	mov edi, [.object]
	mov ecx, [.object_size]
	rep cmpsb
	je .found

	pop esi
	inc esi
	jmp .find_loop

.found:
	pop eax
	ret

.no:
	mov eax, -1
	ret

.object			dd 0
.object_size		dd 0
.end_dsdt		dd 0

; acpi_sleep:
; Enters an ACPI sleep state
; In\	AL = Sleep state (0 -> 5)
; Out\	Nothing (should never return -- returning at all indicates a failure)

acpi_sleep:
	push eax

	add al, 48
	mov [.sleep_object+2], al

	mov esi, .starting_msg
	call kprint

	pop eax
	and eax, 0xFF
	call int_to_string
	call kprint

	mov esi, .starting_msg2
	call kprint

	cmp [acpi_support], 0
	je .return

	call acpi_enter

	mov esi, .sleep_object
	call acpi_dsdt_find		; find the sleep package in the dsdt
	cmp eax, -1
	je .try_ssdt

	jmp .get_values

.try_ssdt:
	; at least in qemu, the sleep objects are in the ssdt and not the dsdt
	mov esi, .sleep_object
	call acpi_ssdt_find
	cmp eax, -1
	je .return

.get_values:
	mov esi, eax
	add esi, 7

.find_a:
	lodsb
	cmp al, AML_OPCODE_BYTEPREFIX
	je .a_prefix

	mov [.a], al		; Zero, One and Ones don't take byteprefixes
	jmp .find_b

.a_prefix:
	lodsb
	mov [.a], al

.find_b:
	lodsb
	cmp al, AML_OPCODE_BYTEPREFIX
	je .b_prefix

	mov [.b], al
	jmp .start

.b_prefix:
	lodsb
	mov [.b], al

.start:
	cli		; sensitive area of code ;)

	mov edx, [acpi_fadt.pm1a_control_block]
	in ax, dx
	movzx bx, [.a]
	and bx, 7
	shl bx, 10
	and ax, 0xE3FF
	or ax, bx
	or ax, ACPI_CONTROL_SLEEP
	out dx, ax

	mov edx, [acpi_fadt.pm1b_control_block]
	cmp edx, 0
	je .return
	movzx bx, [.b]
	and bx, 7
	shl bx, 10
	and ax, 0xE3FF
	or ax, bx
	or ax, ACPI_CONTROL_SLEEP
	out dx, ax

.return:
	call iowait
	call iowait
	call iowait
	call iowait

	mov esi, .fail_msg
	call kprint

	call acpi_leave
	ret

.starting_msg		db "Attempting to enter ACPI sleep state S",0
.starting_msg2		db "...",10,0
.fail_msg		db "Failed to enter ACPI sleep state.",10,0
.sleep_object		db "_SX_",AML_OPCODE_PACKAGE,AML_OPCODE_ZERO
.a			db 0
.b			db 0





