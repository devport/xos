
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

divide_text			db "Division error.",0
debug_text			db "Debug interrupt.",0
nmi_text			db "Non-maskable interrupt.",0
breakpoint_text			db "Breakpoint.",0
overflow_text			db "Overflow exception.",0
bound_text			db "BOUND range overflow.",0
opcode_text			db "Undefined opcode.",0
device_text			db "Device not present.",0
double_text			db "Double fault.",0
coprocessor_text		db "Coprocessor segment overrun.",0
tss_text			db "Corrupt TSS.",0
segment_text			db "Memory segment not present.",0
stack_text			db "Stack segment error.",0
gpf_text			db "General protection fault.",0
page_text			db "Page fault.",0
reserved_text			db "Reserved exception.",0
floating_text			db "x87 floating point error.",0
alignment_text			db "Alignment check.",0
machine_text			db "Machine check.",0
simd_text			db "SIMD floating point error.",0
virtual_text			db "Virtualization exception.",0
security_text			db "Security exception.",0

dump_eax			dd 0
dump_ebx			dd 0
dump_ecx			dd 0
dump_edx			dd 0
dump_esi			dd 0
dump_edi			dd 0
dump_ebp			dd 0
dump_esp			dd 0
dump_cr0			dd 0
dump_cr2			dd 0
dump_cr3			dd 0
dump_cr4			dd 0
dump_eflags			dd 0
dump_cs				dw 0
dump_ss				dw 0
dump_ds				dw 0
dump_es				dw 0

; install_exceptions:
; Installs exception handlers

install_exceptions:
	mov al, 0
	mov ebp, divide_handler
	call install_isr

	mov al, 1
	mov ebp, debug_handler
	call install_isr

	mov al, 2
	mov ebp, nmi_handler
	call install_isr

	mov al, 3
	mov ebp, breakpoint_handler
	call install_isr

	mov al, 4
	mov ebp, overflow_handler
	call install_isr

	mov al, 5
	mov ebp, bound_handler
	call install_isr

	mov al, 6
	mov ebp, opcode_handler
	call install_isr

	mov al, 7
	mov ebp, device_handler
	call install_isr

	mov al, 8
	mov ebp, double_handler
	call install_isr

	mov al, 9
	mov ebp, coprocessor_handler
	call install_isr

	mov al, 10
	mov ebp, tss_handler
	call install_isr

	mov al, 11
	mov ebp, segment_handler
	call install_isr

	mov al, 12
	mov ebp, stack_handler
	call install_isr

	mov al, 13
	mov ebp, gpf_handler
	call install_isr

	mov al, 14
	mov ebp, page_handler
	call install_isr

	mov al, 15
	mov ebp, reserved_handler
	call install_isr

	mov al, 16
	mov ebp, floating_handler
	call install_isr

	mov al, 17
	mov ebp, alignment_handler
	call install_isr

	mov al, 18
	mov ebp, machine_handler
	call install_isr

	mov al, 19
	mov ebp, simd_handler
	call install_isr

	mov al, 20
	mov ebp, virtual_handler
	call install_isr

	mov al, 21
	mov ebp, reserved_handler
	call install_isr

	mov al, 22
	mov ebp, reserved_handler
	call install_isr

	mov al, 23
	mov ebp, reserved_handler
	call install_isr

	mov al, 24
	mov ebp, reserved_handler
	call install_isr

	mov al, 25
	mov ebp, reserved_handler
	call install_isr

	mov al, 26
	mov ebp, reserved_handler
	call install_isr

	mov al, 27
	mov ebp, reserved_handler
	call install_isr

	mov al, 28
	mov ebp, reserved_handler
	call install_isr

	mov al, 29
	mov ebp, reserved_handler
	call install_isr

	mov al, 30
	mov ebp, security_handler
	call install_isr

	mov al, 31
	mov ebp, reserved_handler
	call install_isr

	ret

; exception_handler:
; Common code for exception handlers

exception_handler:
	cli
	call save_regs
	call use_front_buffer

	mov [debug_mode],1

	mov ebx, 0
	call clear_screen

	mov eax, [esp+16]	; CS
	mov [dump_cs], ax

	mov eax, [esp+16+4]	; EFLAGS
	mov [dump_eflags], eax

	mov eax, [esp+16+8]	; ESP
	mov [dump_esp], eax

	mov eax, [esp+12+4+4+4+4]
	mov [dump_ss], ax

	mov esi, .msg
	call kprint
	mov esi, [esp+4]
	call kprint
	mov esi, newline
	call kprint

	mov esi, .msg2
	call kprint
	mov eax, [esp+8]
	call hex_dword_to_string
	call kprint

	mov esi, .msg3
	call kprint
	mov eax, [esp+12]		; eip
	call hex_dword_to_string
	call kprint
	mov esi, newline
	call kprint

	call dump_regs

	jmp $

.msg			db "KERNEL PANIC: ",0
.msg2			db "Error code: 0x",0
.msg3			db ", fault address: 0x",0

; save_regs:
; Saves registers for dumping

save_regs:
	mov [dump_eax], eax
	mov [dump_ebx], ebx
	mov [dump_ecx], ecx
	mov [dump_edx], edx
	mov [dump_esi], esi
	mov [dump_edi], edi
	mov [dump_ebp], ebp

	mov eax, cr0
	mov [dump_cr0], eax

	mov eax, cr2
	mov [dump_cr2], eax

	mov eax, cr3
	mov [dump_cr3], eax

	mov eax, cr4
	mov [dump_cr4], eax

	mov ax, ds
	mov [dump_ds], ax

	mov ax, es
	mov [dump_es], ax

	ret

; dump_regs:
; Dumps registers

dump_regs:
	mov esi, .msg
	call kprint

	mov esi, .eax
	call kprint
	mov eax, [dump_eax]
	call hex_dword_to_string
	call kprint

	mov esi, .ebx
	call kprint
	mov eax, [dump_ebx]
	call hex_dword_to_string
	call kprint

	mov esi, .ecx
	call kprint
	mov eax, [dump_ecx]
	call hex_dword_to_string
	call kprint

	mov esi, .edx
	call kprint
	mov eax, [dump_edx]
	call hex_dword_to_string
	call kprint

	mov esi, newline
	call kprint


	mov esi, .esi
	call kprint
	mov eax, [dump_esi]
	call hex_dword_to_string
	call kprint

	mov esi, .edi
	call kprint
	mov eax, [dump_edi]
	call hex_dword_to_string
	call kprint

	mov esi, .esp
	call kprint
	mov eax, [dump_esp]
	call hex_dword_to_string
	call kprint

	mov esi, .ebp
	call kprint
	mov eax, [dump_ebp]
	call hex_dword_to_string
	call kprint

	mov esi, newline
	call kprint

	mov esi, .cs
	call kprint
	mov ax, [dump_cs]
	call hex_word_to_string
	call kprint

	mov esi, .ss
	call kprint
	mov ax, [dump_ss]
	call hex_word_to_string
	call kprint

	mov esi, .ds
	call kprint
	mov ax, [dump_ds]
	call hex_word_to_string
	call kprint

	mov esi, .es
	call kprint
	mov ax, [dump_es]
	call hex_word_to_string
	call kprint

	mov esi, .eflags
	call kprint
	mov eax, [dump_eflags]
	call hex_dword_to_string
	call kprint

	mov esi, newline
	call kprint

	mov esi, .cr0
	call kprint
	mov eax, [dump_cr0]
	call hex_dword_to_string
	call kprint

	mov esi, .cr2
	call kprint
	mov eax, [dump_cr2]
	call hex_dword_to_string
	call kprint

	mov esi, .cr3
	call kprint
	mov eax, [dump_cr3]
	call hex_dword_to_string
	call kprint

	mov esi, .cr4
	call kprint
	mov eax, [dump_cr4]
	call hex_dword_to_string
	call kprint

	mov esi, newline
	call kprint

	mov esi, .end_msg
	call kprint

	ret

.msg			db " --- beginning register dump at time of fault --- ",10,0
.eax			db "  eax: ",0
.ebx			db "  ebx: ",0
.ecx			db "  ecx: ",0
.edx			db "  edx: ",0
.esi			db "  esi: ",0
.edi			db "  edi: ",0
.esp			db "  esp: ",0
.ebp			db "  ebp: ",0
.eflags			db "  eflags: ",0
.cs			db "  cs: ",0
.ss			db "  ss: ",0
.ds			db "  ds: ",0
.es			db "  es: ",0
.cr0			db "  cr0: ",0
.cr2			db "  cr2: ",0
.cr3			db "  cr3: ",0
.cr4			db "  cr4: ",0
.end_msg		db " --- end of register dump --- ",10,0

; early_boot_error:
; Handler for early boot errors, before the VESA Framebuffer is properly mapped
; In\	ESI = Text to display
; Out\	Nothing

early_boot_error:
	cli

	call kprint

	mov [.string], esi

	mov al, 0xFF			; no PIC
	out 0x21, al
	out 0xa1, al

	mov eax, cr0
	and eax, 0x7FFFFFFF
	mov cr0, eax

	call vmm_init

	mov eax, VBE_BACK_BUFFER
	mov ebx, [screen.framebuffer]
	mov ecx, 2048
	mov dl, PAGE_PRESENT OR PAGE_WRITEABLE
	call vmm_map_memory

	mov ebx, 0x800000
	call clear_screen

	mov ebx, 0x800000
	mov ecx, 0xD8D8D8
	call set_text_color

	mov esi, .title
	mov cx, 16
	mov dx, 16
	call print_string

	mov esi, [.string]
	mov cx, 16
	mov dx, 32
	call print_string

	cli
	hlt

.string				dd 0
.title				db "An error has occured and xOS has failed to start. Error information: ",0

; Exception Handlers...

divide_handler:
	push 0
	push divide_text
	call exception_handler

	add esp, 8
	iret

debug_handler:
	push 0
	push debug_text
	call exception_handler

	add esp, 8
	iret

nmi_handler:
	push 0
	push nmi_text
	call exception_handler

	add esp, 8
	iret

breakpoint_handler:
	push 0
	push breakpoint_text
	call exception_handler

	add esp, 8
	iret

overflow_handler:
	push 0
	push overflow_text
	call exception_handler

	add esp, 8
	iret

bound_handler:
	push 0
	push bound_text
	call exception_handler

	add esp, 8
	iret

opcode_handler:
	push 0
	push opcode_text
	call exception_handler

	add esp, 8
	iret

device_handler:
	push 0
	push device_text
	call exception_handler

	add esp, 8
	iret

double_handler:
	push double_text
	call exception_handler

	add esp, 8
	iret

coprocessor_handler:
	push 0
	push coprocessor_text
	call exception_handler

	add esp, 8
	iret

tss_handler:
	push tss_text
	call exception_handler

	add esp, 8
	iret

segment_handler:
	push segment_text
	call exception_handler

	add esp, 8
	iret

stack_handler:
	push stack_text
	call exception_handler

	add esp, 8
	iret

gpf_handler:
	push gpf_text
	call exception_handler

	add esp, 8
	iret

page_handler:
	push page_text
	call exception_handler

	add esp, 8
	iret

reserved_handler:
	push 0
	push reserved_text
	call exception_handler

	add esp, 8
	iret

floating_handler:
	push 0
	push floating_text
	call exception_handler

	add esp, 8
	iret

alignment_handler:
	push alignment_text
	call exception_handler

	add esp, 8
	iret

machine_handler:
	push 0
	push machine_text
	call exception_handler

	add esp, 8
	iret

simd_handler:
	push 0
	push simd_text
	call exception_handler

	add esp, 8
	iret

virtual_handler:
	push 0
	push virtual_text
	call exception_handler

	add esp, 8
	iret

security_handler:
	push security_text
	call exception_handler

	add esp, 8
	iret






