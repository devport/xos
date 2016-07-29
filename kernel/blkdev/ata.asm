
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

; Default IO ports used by ISA ATA
; For PCI IDE, the base ports must be gotten from PCI BARs 0 and 1
ATA_PRIMARY_BASE		= 0x1F0
ATA_SECONDARY_BASE		= 0x170

; ATA Commands
ATA_IDENTIFY			= 0xEC
ATA_FLUSH			= 0xE7
ATA_READ_LBA28			= 0x20
ATA_WRITE_LBA28			= 0x30
ATA_READ_LBA48			= 0x24
ATA_WRITE_LBA48			= 0x34

ata_primary			dw ATA_PRIMARY_BASE
ata_secondary			dw ATA_SECONDARY_BASE

pci_ide_bus			db 0
pci_ide_dev			db 0
pci_ide_function		db 0

; ata_detect:
; Detect ATA bus and ATA/ATAPI devices

ata_detect:
	; first detect PCI IDE controller
	mov ax, 0x0101
	call pci_get_device_class

	mov [pci_ide_bus], al
	mov [pci_ide_dev], ah
	mov [pci_ide_function], bl

	cmp [pci_ide_bus], 0xFF
	je .isa

	mov esi, .pci_msg
	call kprint
	mov al, [pci_ide_bus]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [pci_ide_dev]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [pci_ide_function]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

.detect_primary_port:
	; detect I/O ports from the PCI configuration
	mov al, [pci_ide_bus]
	mov ah, [pci_ide_dev]
	mov bl, [pci_ide_function]
	mov bh, PCI_BAR0
	call pci_read_dword

	cmp ax, 1
	jle .primary_standard
	and ax, 0xFFFC
	mov [ata_primary], ax

	jmp .detect_secondary_port

.primary_standard:
	mov [ata_primary], ATA_PRIMARY_BASE	; if BAR0 of PCI IDE is 0 or 1, then it uses standard isa ports

.detect_secondary_port:
	mov al, [pci_ide_bus]
	mov ah, [pci_ide_dev]
	mov bl, [pci_ide_function]
	mov bh, PCI_BAR1
	call pci_read_dword

	cmp ax, 1
	jle .secondary_standard
	and ax, 0xFFFC
	mov [ata_secondary], ax
	jmp .detect_drives

.secondary_standard:
	mov [ata_secondary], ATA_SECONDARY_BASE
	jmp .detect_drives

.isa:
	; to detect ISA ATA, use the "floating bus" technique
	mov dx, ATA_PRIMARY_BASE+7	; status
	in al, dx
	cmp al, 0xFF
	je .no_ata

	; use the default IO ports at 0x1F0 and 0x170
	mov [ata_primary], ATA_PRIMARY_BASE
	mov [ata_secondary], ATA_SECONDARY_BASE

.detect_drives:
	mov esi, .ports_msg
	call kprint
	mov ax, [ata_primary]
	call hex_word_to_string
	call kprint
	mov esi, .ports_msg2
	call kprint
	mov ax, [ata_secondary]
	call hex_word_to_string
	call kprint
	mov esi, newline
	call kprint

	; reset the ATA channels
	call ata_reset

	; disable ATA IRQs
	mov dx, [ata_primary]
	add dx, 0x206
	mov al, 2
	out dx, al

	mov dx, [ata_secondary]
	add dx, 0x206
	mov al, 2
	out dx, al

	; detect the devices

	ret

.no_ata:
	mov esi, .no_ata_msg
	call kprint
	ret

.pci_msg			db "IDE controller at PCI slot ",0
.ports_msg			db "ATA channels at ports 0x",0
.ports_msg2			db ", 0x",0
.colon				db ":",0
.no_ata_msg			db "ATA not found.",10,0

; ata_reset:
; Resets the ATA channels

ata_reset:
	push edx
	push eax

	mov dx, [ata_primary]
	add dx, 0x206
	mov al, 4
	out dx, al

	mov dx, [ata_secondary]
	add dx, 0x206
	out dx, al

	call iowait
	call iowait

	mov dx, [ata_primary]
	add dx, 0x206
	mov al, 0
	out dx, al

	mov dx, [ata_secondary]
	add dx, 0x206
	out dx, al

	call iowait
	call iowait

	pop eax
	pop edx
	ret

; ata_identify:
; Identifies an ATA device
; In\	DL = Bit 0 -> set for slave device; bit 1 -> set for secondary controller
; In\	EDI = Buffer to save information
; Out\	EFLAGS.CF = 0 on success

ata_identify:
	test dl, 2	; secondary controller?



