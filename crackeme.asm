.model tiny
.code
org 100h


start:

    mov dx, pass_msg
    mov ah, 09h        ; Вывод строки
    int 21h

    mov di, password   ; Указатель на ожидаемый пароль
    mov si, input_buf  ; Указатель на введённый пароль

    ; Ввод строки
    mov dx, input_buf  ; Буфер для ввода
    mov ah, 0Ah
    int 21h

    ; Сравниваем введённый пароль с заданным
    mov cx, pass_len   ; Длина пароля
    mov di, password
    mov si, input_buf+2 ; Пропустить первый байт (макс. длина) и второй (факт. длина)

compare:
    mov al, [di]
    cmp al, [si]
    jne access_denied  ; Если не совпадает, перейти
    inc di
    inc si
    loop compare

    ; Если дошли до сюда, значит пароль совпал
    mov dx, access_granted
    jmp print_message

access_denied:
    mov dx, access_denied_msg

print_message:
    mov ah, 09h
    int 21h

    ; Завершение программы
    mov ah, 4Ch
    int 21h

.data
    pass_msg db 'Enter password: $'
    password db 'secret'  ; Пароль
    pass_len equ $ - password

    input_buf db 10, 0     ; 10 - макс. длина, 0 - фактическая длина (DOS заполнит)
    input_data db 10 dup(0) ; Буфер для ввода

    access_granted db 13, 10, 'Access granted!$', 13, 10
    access_denied_msg db 13, 10, 'Access denied!$', 13, 10

end start
