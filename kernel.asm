[bits 64]
[org 0x100000]

VGA equ 0xB8000
W equ 80
H equ 25

section .bss
input      resb 128
cmd        resb 32
arg        resb 64
pwd        resb 256
username   resb 32
password   resb 32
root_mode  resb 1
fs_entries resb 1024
cur_x      resw 1
cur_y      resw 1

section .text
_start:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov rsp, 0x200000

    call clear_screen
    call init_system
    call show_banner

main_loop:
    call show_prompt
    call read_input
    call parse_command
    jmp main_loop

clear_screen:
    mov rdi, VGA
    mov rcx, W*H
    mov rax, 0x0720
.clr_loop:
    mov [rdi], rax
    add rdi, 2
    loop .clr_loop
    mov word [cur_x], 0
    mov word [cur_y], 0
    ret

print_string:
    mov rdi, VGA
    imul rax, [cur_y], W*2
    add rax, [cur_x]*2
    add rdi, rax
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, 10
    je .newline
    mov ah, 0x0F
    mov [rdi], ax
    add rdi, 2
    inc word [cur_x]
    cmp word [cur_x], W
    jb .loop
.newline:
    inc word [cur_y]
    mov word [cur_x], 0
    jmp print_string.loop
.done:
    ret

show_prompt:
    mov rsi, prompt_open
    call print_string
    
    mov rsi, username
    call print_string
    
    cmp byte [root_mode], 1
    jne .user
    mov rsi, root_suffix
    call print_string
.user:
    mov rsi, prompt_close
    call print_string
    ret

read_input:
    lea rdi, [input]
    xor rcx, rcx
.read_loop:
    call kb_wait
    call kb_getchar
    cmp al, 13
    je .enter
    cmp rcx, 127
    jae .read_loop
    mov [rdi+rcx], al
    inc rcx
    mov rsi, rsp
    push rax
    call print_string
    pop rax
    jmp .read_loop
.enter:
    mov byte [rdi+rcx], 0
    mov al, 10
    mov ah, 0x0F
    mov rsi, rsp
    mov [rsi], ax
    call print_string
    ret

kb_wait:
    in al, 0x64
    test al, 1
    jz kb_wait
    ret

kb_getchar:
    in al, 0x60
    call scancode_to_char
    ret

scancode_to_char:
    cmp al, 0x02  ; 1
    je .one
    cmp al, 0x1E  ; a
    je .a
    cmp al, 0x1F  ; s
    je .s
    cmp al, 0x20  ; d
    je .d
    xor al, al
    ret
.one: mov al, '1'  ret
.a:   mov al, 'a'  ret
.s:   mov al, 's'  ret
.d:   mov al, 'd'  ret

parse_command:
    lea rsi, [input]
    lea rdi, [cmd]
.parse_cmd:
    lodsb
    cmp al, ' '
    je .cmd_done
    test al, al
    jz .cmd_done
    stosb
    jmp .parse_cmd
.cmd_done:
    mov byte [rdi], 0

    lea rdi, [arg]
.skip_space:
    lodsb
    cmp al, ' '
    je .skip_space
    test al, al
    jz .no_arg
.copy_arg:
    stosb
    lodsb
    test al, al
    jnz .copy_arg
.no_arg:
    mov byte [rdi], 0

    lea rsi, [cmd]
    
    mov rdi, cmd_ls
    call strcmp
    je do_ls
    
    mov rdi, cmd_help
    call strcmp
    je do_help
    
    mov rdi, cmd_clear
    call strcmp
    je do_clear
    
    mov rdi, cmd_flow
    call strcmp
    je do_flow
    
    mov rsi, unknown_msg
    jmp print_string

do_ls:
    mov rsi, ls_output
    call print_string
    ret

do_help:
    mov rsi, help_msg
    call print_string
    ret

do_clear:
    call clear_screen
    ret

do_flow:
    mov rsi, sudo_prompt
    call print_string
    lea rdi, [input]
    call read_password_hidden
    lea rsi, [input]
    lea rdi, [password]
    call strcmp
    je .success
    mov rsi, wrong_pass
    jmp print_string
.success:
    mov byte [root_mode], 1
    mov rsi, sudo_success
    call print_string
    ret

strcmp:
.loop:
    mov al, [rsi]
    mov ah, [rdi]
    cmp al, ah
    jne .fail
    test al, al
    jz .success
    inc rsi
    inc rdi
    jmp .loop
.success:
    mov al, 1
    ret
.fail:
    xor al, al
    ret

read_password_hidden:
    xor rcx, rcx
.loop:
    call kb_wait
    call kb_getchar
    cmp al, 13
    je .done
    cmp rcx, 31
    jae .loop
    mov [rdi+rcx], al
    inc rcx
    jmp .loop
.done:
    mov byte [rdi+rcx], 0
    ret

init_system:
    mov word [username], 'fl'
    mov word [username+2], 'ow'
    mov byte [username+4], 0
    mov dword [password], 0x3233313033  ; os123
    mov byte [root_mode], 0
    ret

show_banner:
    mov rsi, banner_msg
    call print_string
    ret

section .data
banner_msg: db "FlowOS 1.0 - Pure x86_64 ASM OS",10,10,0
prompt_open: db "[",0
root_suffix: db "$root ",0
prompt_close: db "$ ",0
cmd_ls: db "ls",0
cmd_help: db "help",0
cmd_clear: db "clear",0
cmd_flow: db "flow",0
unknown_msg: db "Unknown command. Try 'help'",10,0
ls_output: db "test.txt",10,"config.sys",10,0
help_msg: db "Commands:",10
         db "  ls     - list files",10
         db "  help   - this help",10
         db "  clear  - clear screen",10
         db "  flow   - sudo access",10,0
sudo_prompt: db "[sudo] password: ",0
sudo_success: db "Root access granted!",10,0
wrong_pass: db "Wrong password!",10,0