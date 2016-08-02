
;; xOS32
;; Copyright (C) 2016 by Omar Mohammad, all rights reserved.

use32

;
; struct task {
; u16 state;		// 00
; u16 parent;		// 02
; u32 eip;		// 04
; u32 esp;		// 08
; u32 eflags;		// 0C
; u32 pmem_base;	// 10
; u32 mem_size;		// 14
; u32 reserved1;	// 18
; u32 reserved2;	// 1C
; };
;
;
; sizeof(task) = 32;
;

TASK_STATE		= 0x00
TASK_PARENT		= 0x02
TASK_EIP		= 0x04
TASK_ESP		= 0x08
TASK_EFLAGS		= 0x0C
TASK_PMEM_BASE		= 0x10
TASK_MEM_SIZE		= 0x14
TASK_RESERVED1		= 0x18
TASK_RESERVED2		= 0x1C
TASK_SIZE		= 0x20

; Each Task Gets 1/10 Second Execution Time
TASK_TIMESLICE		= TIMER_FREQUENCY/10

; Task State Flags
TASK_PRESENT		= 0x0001
TASK_SLEEPING		= 0x0002

; Stack Frame for IRET
IRET_EIP		= 0x0000
IRET_CS			= 0x0004
IRET_EFLAGS		= 0x0008
IRET_ESP		= 0x000C
IRET_SS			= 0x0010

; Default Stack Size of a Task
TASK_STACK		= 65536		; 64 KB

; Load Address of a Task
TASK_LOAD_ADDR		= 0x8000000	; 128 MB

MAXIMUM_TASKS		= 32	; probably expand this in the future?

running_tasks		dw 0
current_task		dw 0
task_structure		dd 0
idle_time		dd 0
nonidle_time		dd 0

; tasking_init:
; Initializes the multitasking subsystem

tasking_init:
	mov esi, .msg
	call kprint

	mov ecx, MAXIMUM_TASKS*TASK_SIZE
	call kmalloc
	mov [task_structure], eax

	; mark the first task (PID 0) as present
	; this prevents user applications from taking PID 0
	; PID 0 really is the Idle task, which just Halts the CPU in an infinite loop
	mov word[eax], TASK_PRESENT
	mov [running_tasks], 1
	mov [current_task], 0

	ret

.msg			db "Initialize multitasking...",10,0

; get_free_task:
; Finds a free task
; In\	Nothing
; Out\	EAX = PID of free task, -1 on error

get_free_task:
	mov [.pid], 1

	cmp [running_tasks], MAXIMUM_TASKS
	jge .no

.loop:
	cmp [.pid], MAXIMUM_TASKS
	jge .no

	mov eax, [.pid]
	shl eax, 5	; mul 32
	add eax, [task_structure]
	test word[eax], TASK_PRESENT
	jz .done

	inc [.pid]
	jmp .loop

.done:
	mov edi, eax
	mov eax, 0
	mov ecx, TASK_SIZE
	rep stosb

	mov eax, [.pid]
	ret

.no:
	mov eax, -1
	ret

.pid			dd 0

; create_task_memory:
; Creates a task from memory
; In\	EDX = Entry point
; Out\	EAX = PID

create_task_memory:
	mov [.entry], edx

	call get_free_task
	cmp eax, -1
	je .no
	mov [.pid], eax

	; allocate a stack ;)
	mov ecx, TASK_STACK
	call malloc
	add eax, TASK_STACK
	mov [.stack], eax

	; create the task structure
	mov edi, [.pid]
	shl edi, 5		; mul 32
	add edi, [task_structure]
	mov word[edi], TASK_PRESENT

	mov ax, [current_task]
	mov [edi+TASK_PARENT], ax

	mov eax, [.entry]
	mov [edi+TASK_EIP], eax
	mov dword[edi+TASK_EFLAGS], 0x202

	mov eax, [.stack]
	mov [edi+TASK_ESP], eax

	; ready ;)
	inc [running_tasks]
	mov eax, [.pid]
	ret

.no:
	mov eax, -1
	ret

.entry			dd 0
.pid			dd 0
.stack			dd 0

; yield:
; Gives control to the next task

yield:
	cli		; sensitive area of code! ;)

	cmp [running_tasks], 1
	jle .idle

	cmp [current_task], 0		; if we're not running the idle task --
	jne .save_state			; -- then we need to save the task's EIP, stack and EFLAGS

.next:
	inc [current_task]

.loop:
	movzx eax, [current_task]
	cmp eax, MAXIMUM_TASKS
	jge .idle

	shl eax, 5
	add eax, [task_structure]
	test word[eax], TASK_PRESENT
	jz .next

	; Execute this task in ring 3
	mov dx, 0x23
	mov ds, dx
	mov es, dx
	mov fs, dx
	mov gs, dx

	push 0x23		; SS
	mov edx, [eax+TASK_ESP]
	push edx		; ESP
	mov edx, [eax+TASK_EFLAGS]
	push edx		; EFLAGS
	push 0x1B		; CS
	mov edx, [eax+TASK_EIP]
	push edx		; EIP

	iret

.save_state:
	;add esp, 4

	movzx eax, [current_task]
	shl eax, 5
	add eax, [task_structure]

	mov edx, [esp+4]		; eip
	mov [eax+TASK_EIP], edx

	mov edx, [esp+4+IRET_ESP]	; esp
	mov [eax+TASK_ESP], edx

	mov edx, [esp+4+IRET_EFLAGS]	; eflags
	mov [eax+TASK_EFLAGS], edx

	;sub esp, 4	; restore stack
	jmp .next

.idle:
	mov [current_task], 0
	add esp, 4		; clean up the stack
	jmp idle_process	; if no processes are running, keep the CPU usage low




