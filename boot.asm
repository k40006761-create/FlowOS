[org 0x7C00]
[bits 16]

KERNEL_SECTORS equ 64
KERNEL_LBA     equ 1
KERNEL_PHYS    equ 0x100000

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl
    
    ; A20 line
    in al, 0x92
    or al, 2
    out 0x92, al

    call boot_banner

    ; Load kernel
    mov bx, KERNEL_PHYS>>4
    mov es, bx
    xor bx, bx
    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0
    mov cl, KERNEL_LBA+1
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc error

    lgdt [gdt_desc]
    mov eax, cr0
    or al, 1
    mov cr0, eax
    jmp 8:prot_mode

error:
    mov si, err_msg
    call print
    hlt

boot_banner:
    mov ax, 3
    int 0x10
    mov si, banner
    call print_banner
    mov si, loading
    call print_centered
    ret

print_banner:
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, 10
    je .nl
    mov ah, 0x0A
    int 0x10
    jmp print_banner
.nl:
    lodsb
    mov al, 10
    mov ah, 0x0E
    int 0x10
    jmp print_banner
.done: ret

print:
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print
.done: ret

print_centered:
    push si
    mov cx, 0
.cnt:
    lodsb
    test al, al
    jz .done_cnt
    inc cx
    jmp .cnt
.done_cnt:
    pop si
    mov ax, 80
    sub al, cl
    shr al, 1
    mov cl, al
.pad:
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    loop .pad
    call print
    mov al, 10
    mov ah, 0x0E
    int 0x10
    ret

[bits 32]
prot_mode:
    mov ax, 16
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 8:long_mode

[bits 64]
long_mode:
    mov rax, KERNEL_PHYS
    jmp rax

gdt:
    dq 0
    dq 0x00A09A000000FFFF
    dq 0x00A092000000FFFF
gdt_end:

gdt_desc:
    dw gdt_end-gdt-1
    dd gdt

banner:
db " ________ ___       ________  ___       __   ________  ________      ",10
db "|\  _____\\  \     |\   __  \|\  \     |\  \|\   __  \|\   ____\     ",10
db "\ \  \__/\ \  \    \ \  \|\  \ \  \    \ \  \ \  \|\  \ \  \___|_    ",10
db " \ \   __\\ \  \    \ \  \\\  \ \  \  __\ \  \ \  \\\  \ \_____  \   ",10
db "  \ \  \_| \ \  \____\ \  \\\  \ \  \|\__\_\  \ \  \\\  \|____|\  \  ",10
db "   \ \__\   \ \_______\ \_______\ \____________\ \_______\____\_\  \ ",10
db "    \|__|    \|_______|\|_______|\|____________|\|_______|\_________\",10
db "                                                         \|_________|",10,0

loading: db "Loading FlowOS...",0
err_msg: db "Disk error!",13,10,0
boot_drive: db 0

times 510-($-$$) db 0
dw 0xAA55