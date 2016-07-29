
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; Maximum Buses/Device/Functions
PCI_MAX_BUS		= 255	; 256 buses
PCI_MAX_DEV		= 31	; up to 32 devices per bus
PCI_MAX_FUNCTION	= 7	; up to 7 functions per device

; PCI Configuration Registers
PCI_DEVICE_VENDOR	= 0x00
PCI_STATUS_COMMAND	= 0x04
PCI_CLASS		= 0x08
PCI_HEADER_TYPE		= 0x0C
PCI_BAR0		= 0x10
PCI_BAR1		= 0x14
PCI_BAR2		= 0x18
PCI_BAR3		= 0x1C
PCI_BAR4		= 0x20
PCI_BAR5		= 0x24
PCI_CARDBUS		= 0x28
PCI_SUBSYSTEM		= 0x2C
PCI_EXPANSION_ROM	= 0x30
PCI_CAPABILITIES	= 0x34
PCI_RESERVED		= 0x38
PCI_IRQ			= 0x3C

pci_last_bus		db 0

; pci_read_dword:
; Reads a DWORD from the PCI bus
; In\	AL = Bus number
; In\	AH = Device number
; In\	BL = Function
; In\	BH = Offset
; Out\	EAX = DWORD from PCI bus

pci_read_dword:
	pusha
	mov [.bus], al
	mov [.slot], ah
	mov [.function], bl
	mov [.offset], bh

	mov eax, 0
	movzx ebx, [.bus]
	shl ebx, 16
	or eax, ebx
	movzx ebx, [.slot]
	shl ebx, 11
	or eax, ebx
	movzx ebx, [.function]
	shl ebx, 8
	or eax, ebx
	movzx ebx, [.offset]
	and ebx, 0xFC
	or eax, ebx
	or eax, 0x80000000

	mov edx, 0xCF8
	out dx, eax

	call iowait
	mov edx, 0xCFC
	in eax, dx
	mov [.tmp], eax
	popa
	mov eax, [.tmp]
	ret

.tmp				dd 0
.bus				db 0
.function			db 0
.slot				db 0
.offset				db 0

; pci_write_dword:
; Writes a DWORD to the PCI bus
; In\	AL = Bus number
; In\	AH = Device number
; In\	BL = Function
; In\	BH = Offset
; In\	EDX = DWORD to write
; Out\	Nothing

pci_write_dword:
	pusha
	mov [.bus], al
	mov [.slot], ah
	mov [.func], bl
	mov [.offset], bh
	mov [.dword], edx

	mov eax, 0
	mov ebx, 0
	mov al, [.bus]
	shl eax, 16
	mov bl, [.slot]
	shl ebx, 11
	or eax, ebx
	mov ebx, 0
	mov bl, [.func]
	shl ebx, 8
	or eax, ebx
	mov ebx, 0
	mov bl, [.offset]
	and ebx, 0xFC
	or eax, ebx
	mov ebx, 0x80000000
	or eax, ebx

	mov edx, 0xCF8
	out dx, eax

	call iowait
	mov eax, [.dword]
	mov edx, 0xCFC
	out dx, eax

	call iowait
	popa
	ret

.dword				dd 0
.tmp				dd 0
.bus				db 0
.func				db 0
.slot				db 0
.offset				db 0

; pci_init:
; Initializes PCI

pci_init:

.loop:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, 0
	mov bh, PCI_DEVICE_VENDOR
	call pci_read_dword
	cmp eax, 0xFFFFFFFF
	je .done

	inc [.device]
	cmp [.device], PCI_MAX_DEV
	jg .next_bus
	jmp .loop

.next_bus:
	mov [.device], 0
	inc [.bus]
	jmp .loop

.done:
	cmp [.device], 0
	jne .yes

	cmp [.bus], 0
	jne .yes

.no:
	mov esi, .no_msg
	call kprint
	ret

.yes:
	mov al, [.bus]
	mov [pci_last_bus], al

	mov esi, .msg
	call kprint
	movzx eax, [pci_last_bus]
	inc eax
	call int_to_string
	call kprint
	mov esi, .msg2
	call kprint
	ret
	

.msg			db "Found ",0
.msg2			db " PCI buses.",10,0
.no_msg			db "No PCI devices/buses found.",10,0
.bus			db 0
.device			db 0

; pci_get_device_class:
; Gets the bus and device number of a PCI device from the class codes
; In\	AH = Class code
; In\	AL = Subclass code
; Out\	AL = Bus number (0xFF if invalid)
; Out\	AH = Device number (0xFF if invalid)
; Out\	BL = Function number (0xFF if invalid)

pci_get_device_class:
	mov [.class], ax
	mov [.bus], 0
	mov [.device], 0
	mov [.function], 0

.find_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, PCI_CLASS
	call pci_read_dword

	shr eax, 16
	cmp ax, [.class]
	je .found_device

.next:

.next_function:
	inc [.function]
	cmp [.function], PCI_MAX_FUNCTION
	jg .next_device
	jmp .find_device

.next_device:
	mov [.function], 0
	inc [.device]
	cmp [.device], PCI_MAX_DEV
	jg .next_bus
	jmp .find_device

.next_bus:
	mov [.device], 0
	inc [.bus]
	mov al, [pci_last_bus]
	cmp [.bus], al
	jl .find_device

.not_found:
	mov ax, 0xFFFF
	mov bl, 0xFF
	ret

.found_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]

	ret

.class				dw 0
.bus				db 0
.device				db 0
.function			db 0

; pci_get_device_class_progif:
; Gets the bus and device number of a PCI device from the class codes and Prog IF code
; In\	AH = Class code
; In\	AL = Subclass code
; In\	BL = Prog IF
; Out\	AL = Bus number (0xFF if invalid)
; Out\	AH = Device number (0xFF if invalid)
; Out\	BL = Function number (0xFF if invalid)

pci_get_device_class_progif:
	mov [.class], ax
	mov [.progif], bl
	mov [.bus], 0
	mov [.device], 0
	mov [.function], 0

.find_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, 8
	call pci_read_dword

	shr eax, 8
	cmp al, [.progif]
	jne .next

	shr eax, 8
	cmp ax, [.class]
	jne .next
	jmp .found_device

.next:

.next_function:
	inc [.function]
	cmp [.function], PCI_MAX_FUNCTION
	jg .next_device
	jmp .find_device

.next_device:
	mov [.function], 0
	inc [.device]
	cmp [.device], PCI_MAX_DEV
	jg .next_bus
	jmp .find_device

.next_bus:
	mov [.device], 0
	inc [.bus]
	mov al, [pci_last_bus]
	cmp [.bus], al
	jl .find_device

.not_found:
	mov ax, 0xFFFF
	mov bl, 0xFF
	ret

.found_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]

	ret

.class				dw 0
.bus				db 0
.device				db 0
.function			db 0
.progif				db 0

; pci_get_device_vendor:
; Gets the bus and device and function of a PCI device from the vendor and device ID
; In\	EAX = Vendor/device combination (low word vendor ID, high word device ID)
; Out\	AL = Bus number (0xFF if invalid)
; Out\	AH = Device number (0xFF if invalid)
; Out\	BL = Function number (0xFF if invalid)

pci_get_device_vendor:
	mov [.dword], eax
	mov [.bus], 0
	mov [.device], 0
	mov [.function], 0

.find_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, 0
	call pci_read_dword

	cmp eax, [.dword]
	je .found_device

.next:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]
	mov bh, 0xC
	call pci_read_dword
	shr eax, 16
	test al, 0x80		; is multifunction?
	jz .next_device

.next_function:
	inc [.function]
	cmp [.function], PCI_MAX_FUNCTION
	jle .find_device

.next_device:
	mov [.function], 0
	inc [.device]
	cmp [.device], PCI_MAX_DEV
	jle .find_device

.next_bus:
	mov [.device], 0
	inc [.bus]
	mov al, [pci_last_bus]
	cmp [.bus], al
	jl .find_device

.no_device:
	mov ax, 0xFFFF
	mov bl, 0xFF
	ret

.found_device:
	mov al, [.bus]
	mov ah, [.device]
	mov bl, [.function]

	ret

.dword				dd 0
.bus				db 0
.device				db 0
.function			db 0


