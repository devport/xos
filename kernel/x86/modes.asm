
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

old_stack			dd 0
bios_cr0			dd 0
bios_cr4			dd 0
kernel_cr0			dd 0
kernel_cr4			dd 0

; gdt:
; Global Descriptor Table
align 32
gdt:
	; 0x00 -- null descriptor
	dq 0

	; 0x08 -- kernel code descriptor
	dw 0xFFFF				; limit low
	dw 0					; base low
	db 0					; base middle
	db 10011010b				; access
	db 11001111b				; flags and limit high
	db 0					; base high

	; 0x10 -- kernel data descriptor
	dw 0xFFFF
	dw 0
	db 0
	db 10010010b
	db 11001111b
	db 0

	; 0x18 -- user code descriptor
	dw 0xFFFF				; limit low
	dw 0					; base low
	db 0					; base middle
	db 11111010b				; access
	db 11001111b				; flags and limit high
	db 0					; base high

	; 0x20 -- user data descriptor
	dw 0xFFFF
	dw 0
	db 0
	db 11110010b
	db 11001111b
	db 0

	; 0x28 -- 16-bit code descriptor
	dw 0xFFFF
	dw 0
	db 0
	db 10011010b
	db 10001111b
	db 0

	; 0x30 -- 16-bit data descriptor
	dw 0xFFFF
	dw 0
	db 0
	db 10010010b
	db 10001111b
	db 0

	; 0x38 -- TSS descriptor
	dw 104
	dw tss
	db 0
	db 11101001b
	db 0
	db 0

end_of_gdt:

; gdtr:
; GDT Pointer
align 32
gdtr:
	.size			dw end_of_gdt - gdt - 1
	.base			dd gdt

; idt:
; Interrupt Descriptor Table
align 32
idt:
	times 256 dw unhandled_isr, 8, 0x8E00, 0
end_of_idt:

; idtr:
; IDT Pointer
align 32
idtr:
	.size			dw end_of_idt - idt - 1
	.base			dd idt

; tss:
; Task State Segment
align 32
tss:
	.prev_tss			dd 0
	.esp0				dd 0			; kernel stack
	.ss0				dd 0x10			; kernel stack segment
	.esp1				dd 0
	.ss1				dd 0
	.esp2				dd 0
	.ss2				dd 0
	.cr3				dd page_directory
	.eip				dd 0
	.eflags				dd 0
	.eax				dd 0
	.ecx				dd 0
	.edx				dd 0
	.ebx				dd 0
	.esp				dd 0
	.ebp				dd 0
	.esi				dd 0
	.edi				dd 0
	.es				dd 0x10			; kernel data segments
	.cs				dd 0x08
	.ss				dd 0x10
	.ds				dd 0x10
	.fs				dd 0x10
	.gs				dd 0x10
	.ldt				dd 0
	.trap				dw 0
	.iomap_base			dw 104			; prevent user programs from using IN/OUT instructions

; unhandled_isr:
; Handler for unhandled ISRs
use32
unhandled_isr:
	iret

; iowait:
; Waits for an I/O operation to complete

iowait:
	out 0x80, al
	out 0x80, al
	ret

; install_isr:
; Installs an interrupt handler
; In\	AL = Interrupt number
; In\	EBP = ISR address
; Out\	Nothing

install_isr:
	and eax, 0xFF
	shl eax, 3
	add eax, idt

	mov word[eax], bp
	shr ebp, 16
	mov word[eax+6], bp

	ret

; set_isr_privledge:
; Sets the privledge of an entry in the IDT
; In\	AL = Interrupt number
; In\	DL = Privledge bitfields
; Out\	Nothing

set_isr_privledge:
	push edx

	and eax, 0xFF
	shl eax, 3
	add eax, idt

	pop edx
	mov byte[eax+5], dl
	ret




