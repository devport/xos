
; en-US keyboard layout scancodes

; Scancodes for the arrow keys ;)
SCANCODE_UP			= 72
SCANCODE_LEFT			= 75
SCANCODE_RIGHT			= 77
SCANCODE_DOWN			= 80

align 16
ascii_codes:
	db 0,27
	db "1234567890-=",8
	db "	"
	db "qwertyuiop[]",13,0
	db "asdfghjkl;'`",0
	db "\zxcvbnm,./",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db "-",0,0,0,"+"
	times 128 - ($-ascii_codes) db 0

align 16
ascii_codes_capslock:
	db 0,27
	db "1234567890-=",8
	db "	"
	db "QWERTYUIOP[]",13,0
	db "ASDFGHJKL;'`",0
	db "\ZXCVBNM,./",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db "-",0,0,0,"+"
	times 128 - ($-ascii_codes_capslock) db 0

align 16
ascii_codes_shift:
	db 0,27
	db "!@#$%^&*()_+",8
	db "	"
	db "QWERTYUIOP{}",13,0
	db "ASDFGHJKL:", '"', "~",0
	db "|ZXCVBNM<>?",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db "-",0,0,0,"+"
	times 128 - ($-ascii_codes_shift) db 0

align 16
ascii_codes_shift_capslock:
	db 0,27
	db "!@#$%^&*()_+",8
	db "	"
	db "qwertyuiop{}",13,0
	db "asdfghjkl:", '"', "~",0
	db "|zxcvbnm<>?",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	db "-",0,0,0,"+"
	times 128 - ($-ascii_codes_shift_capslock) db 0



