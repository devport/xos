
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

;
; This file contains ACPI table routines.
; These include detecting ACPI at all, finding tables, and enabling ACPI using the SMI IO port in the FADT.
; For ACPI runtime (AML, DSDT, shutdown, etc...), see "acpirun.asm" instead.
;

ACPI_SDT_SIZE		= 36	; size of acpi sdt header

; ACPI Event Data
ACPI_EVENT_TIMER		= 1
ACPI_EVENT_BUSMASTER		= 0x10
ACPI_EVENT_GBL			= 0x20
ACPI_EVENT_POWERBUTTON		= 0x100
ACPI_EVENT_SLEEPBUTTON		= 0x200
ACPI_EVENT_RTC			= 0x400
ACPI_EVENT_PCIE_WAKE		= 0x4000
ACPI_EVENT_WAKE			= 0x8000

acpi_support			db 0

macro acpi_gas
{
	.address_space		db 0
	.bit_width		db 0
	.bit_offset		db 0
	.access_size		db 0
	.address		dq 0
}

acpi_rsdp		dd 0
acpi_rsdt		dd 0
acpi_tables		dd 0

; acpi_enter:
; Enters the ACPI subsystem

acpi_enter:
	push eax
	mov eax, cr0
	and eax, 0x7FFFFFFF
	mov cr0, eax
	pop eax
	ret

; acpi_leave:
; Leaves the ACPI subsystem

acpi_leave:
	push eax
	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax
	pop eax
	ret

; acpi_init:
; Detects ACPI

acpi_init:
	; look for ACPI RSDP in low memory between 0xE0000 -> 0xFFFFF
	mov esi, 0xE0000
	mov edi, .rsd_ptr

.loop:
	pusha
	mov ecx, 8
	rep cmpsb
	je .found
	popa

	add esi, 16		; RSDP is always in a 16-byte aligned address
	cmp esi, 0xFFFFF
	jge .no

	jmp .loop

.found:
	popa
	mov [acpi_rsdp], esi

	mov esi, .found_msg
	call kprint
	mov eax, [acpi_rsdp]
	mov al, [eax+15]
	inc al
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	mov eax, [acpi_rsdp]
	mov eax, [eax+16]
	mov [acpi_rsdt], eax	; save RSDT address

	call acpi_enter

	mov eax, [acpi_rsdt]
	mov eax, [eax+4]	; table size
	sub eax, ACPI_SDT_SIZE
	shr eax, 4		; div 4
	mov [acpi_tables], eax	; # of ACPI tables

	mov [acpi_support], 1

	call enable_acpi	; Enable ACPI
	ret

.no:
	mov [acpi_rsdt], 0
	mov [acpi_tables], 0
	mov esi, .no_msg
	call kprint

	ret

.found_msg		db "Found ACPI revision 0x",0
.no_msg			db "ACPI tables not found.",10,0
.rsd_ptr		db "RSD PTR "

; acpi_find_table:
; Searches for an ACPI table
; In\	EAX = 4-byte table name
; Out\	EAX = Pointer to table, -1 on error

acpi_find_table:
	cmp [acpi_support], 0
	je .no

	mov [.sig], eax
	mov [.current_table], 0

	mov esi, [acpi_rsdt]
	add esi, ACPI_SDT_SIZE

.loop:
	mov ecx, [acpi_tables]
	cmp [.current_table], ecx
	jg .no

	mov eax, [esi]		; table address
	mov edx, [.sig]
	cmp [eax], edx
	je .found

	inc [.current_table]
	add esi, 4
	jmp .loop

.found:
	ret

.no:
	mov eax, -1
	ret

.sig			dd 0
.current_table		dd 0
.table			dd 0

; enable_acpi:
; Enables ACPI hardware mode

enable_acpi:
	call acpi_enter

	mov eax, "FACP"		; find the FADT
	call acpi_find_table
	cmp eax, -1
	je .no_fadt

	mov esi, eax
	mov edi, acpi_fadt
	mov ecx, acpi_fadt_size
	rep movsb

	; install irq handler & unmask the irq
	mov ax, [acpi_fadt.sci_interrupt]
	add al, IRQ_BASE
	mov ebp, acpi_irq
	call install_isr

	mov ax, [acpi_fadt.sci_interrupt]
	call pic_unmask

	; check if ACPI is enabled
	mov edx, [acpi_fadt.pm1a_control_block]
	in ax, dx
	test ax, ACPI_CONTROL_ENABLED
	jnz .already_enabled

	mov esi, .enabling
	call kprint

	; enable ACPI
	mov edx, [acpi_fadt.smi_command_port]
	mov al, [acpi_fadt.acpi_enable]
	out dx, al

	; wait for it to be enabled...

.acpi_wait:
	mov edx, [acpi_fadt.pm1a_control_block]
	in ax, dx
	test ax, ACPI_CONTROL_ENABLED
	jz .acpi_wait

.already_enabled:
	mov esi, .msg
	call kprint

	; tell the system we support power/sleep events
	mov edx, [acpi_fadt.pm1a_event_block]
	mov ax, ACPI_EVENT_POWERBUTTON + ACPI_EVENT_SLEEPBUTTON
	out dx, ax

	call acpi_leave
	ret

.no_fadt:
	mov esi, .no_fadt_msg
	call kprint

	call acpi_leave
	ret

.no_fadt_msg		db "No FADT in an ACPI system? Odd...",10,0
.msg			db "System is now in ACPI mode.",10,0
.enabling		db "Enabling ACPI...",10,0

; acpi_irq:
; ACPI IRQ Handler

acpi_irq:
	pusha

	mov esi, .msg
	call kprint

	mov edx, [acpi_fadt.pm1a_event_block]
	in ax, dx
	call hex_word_to_string
	call kprint
	mov esi, newline
	call kprint

	mov al, 0x20
	out 0xA0, al
	out 0x20, al
	popa
	iret

.msg			db "ACPI SCI IRQ: event data 0x",0

; acpi_fadt:
; Structure of ACPI FADT table
align 16
acpi_fadt:
	; ACPI SDT header
	.signature		rb 4
	.length			rd 1
	.revision		rb 1
	.checksum		rb 1
	.oemid			rb 6
	.oem_table_id		rb 8
	.oem_revision		rd 1
	.creator_id		rd 1
	.creator_revision	rd 1

	; FADT table itself
	.firmware_control	rd 1
	.dsdt			rd 1
	.reserved		rb 1

	.preffered_profile	rb 1
	.sci_interrupt		rw 1
	.smi_command_port	rd 1
	.acpi_enable		rb 1
	.acpi_disable		rb 1
	.s4bios_req		rb 1
	.pstate_control		rb 1
	.pm1a_event_block	rd 1
	.pm1b_event_block	rd 1
	.pm1a_control_block	rd 1
	.pm1b_control_block	rd 1
	.pm2_control_block	rd 1
	.pm_timer_block		rd 1
	.gpe0_block		rd 1
	.gpe1_block		rd 1
	.pm1_event_length	rb 1
	.pm1_control_length	rb 1
	.pm2_control_length	rb 1
	.pm_timer_length	rb 1
	.gpe0_length		rb 1
	.gpe1_length		rb 1
	.gpe1_base		rb 1
	.cstate_control		rb 1
	.worst_c2_latency	rw 1
	.worst_c3_latency	rw 1
	.flush_size		rw 1
	.flush_stride		rw 1
	.duty_offset		rb 1
	.duty_width		rb 1
	.day_alarm		rb 1
	.month_alarm		rb 1
	.century		rb 1

	.boot_arch_flags	rw 1
	.reserved2		rb 1
	.flags			rd 1

	acpi_reset_register:	acpi_gas
	acpi_reset_value	rb 1

end_of_acpi_fadt:
acpi_fadt_size			= end_of_acpi_fadt - acpi_fadt




