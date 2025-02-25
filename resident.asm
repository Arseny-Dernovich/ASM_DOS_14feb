.model tiny
.386

.code

org 100h


VIDEOSEG	        equ 0b800h
CONSOLE_ARGS        equ 80h

CONSOLE_WIDTH       equ 80d
CONSOLE_HEIGHT      equ 25d
CONSOLE_MOVEMENT    equ 2d

CENTER_ADDR         equ CONSOLE_WIDTH * (CONSOLE_HEIGHT / 2 + CONSOLE_MOVEMENT) + CONSOLE_WIDTH / 2

FRAME_WIDTH    	    equ 50d
FRAME_HEIGHT        equ 20d

REGS_FRAME_WIDTH    equ 13d
REGS_FRAME_HEIGHT   equ 8d
REGS_FRAME_BORDER_COLOR  equ 00001110b
REGS_FRAME_BCKG_COLOR    equ 00001110b


RIGHT_UP_ADDR       equ (CONSOLE_WIDTH - (REGS_FRAME_WIDTH - REGS_FRAME_WIDTH / 2) + CONSOLE_WIDTH * (REGS_FRAME_HEIGHT / 2))

PARTITION_SYM       equ '/'
LINE_END_SYM        equ '*'

MAX_STR_LEN         equ 150d

REGISTERS_INFO_KEY  equ 0Fh     ; Tab  scan code

REGISTERS_INFO_ON   equ 1
REGISTERS_INFO_OFF  equ 0



Start:
        xor ax, ax
        mov es, ax
        mov bx, 09h * 4

        mov ax, es:[bx]
        mov old09ofs, ax
        mov ax, es:[bx + 2]
        mov old09seg, ax

        cli
        mov word ptr es:[bx], offset InterceptKeyboard
        mov ax, cs
        mov es:[bx + 2], ax
        sti


        xor ax, ax
        mov es, ax
        mov bx, 08h * 4

        mov ax, es:[bx]
        mov old_timer_ofs, ax
        mov ax, es:[bx + 2]
        mov old_timer_seg, ax

        cli
        mov word ptr es:[bx], offset InterceptTimer
        mov ax, cs
        mov es:[bx + 2], ax
        sti


        int 09h

        mov ax, 3100h
        mov dx, offset EOP
        shr dx, 4
        inc dx
        int 21h


;-------------------------------------------------------------------------------------
; Intercepts the 09h interrupt and calls the frame drawing function with register
; information if the specified key was pressed, and erases it if another one was pressed.
; After that, the control is transferred to the 09hr interrupt.
;
; Entry: es = VIDEOSEG
; Exit:  none
; Destr: none
;-------------------------------------------------------------------------------------
InterceptKeyboard   proc

        push ax bx cx dx di si es ds

        push cs
        pop ds

        in  al, 60h
        cmp al, REGISTERS_INFO_KEY
        jne TransferControlToInt_09h

        mov al, FRAME_FLAG
        xor al, 1
        mov byte ptr FRAME_FLAG, al

TransferControlToInt_09h:
        pop ds es si di dx cx bx ax

                    db 0eah        ; jmp 0000:0000
        old09ofs    dw 0
        old09seg    dw 0

        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Intercepts timer interrupt and if FRAME_FLAG = 1 prints a frame with registers
; Entry: es = VIDEOSEG
; Exit:  none
; Destr: none
;-------------------------------------------------------------------------------------
InterceptTimer proc
        push ax bx cx dx di si es ds

        push cs
        pop ds

        mov al, FRAME_FLAG
        cmp al, REGISTERS_INFO_ON
        jne TransferControlToTimer

        push si
        push di
        push dx
        push cx
        push bx
        push ax

        cld             ; moving forward

        pop  bx
        lea  si, AX_INFO
        call ItoA_hex

        pop  bx
        lea  si, BX_INFO
        call ItoA_hex

        pop  bx
        lea  si, CX_INFO
        call ItoA_hex

        pop  bx
        lea  si, DX_INFO
        call ItoA_hex

        pop  bx
        lea  si, DI_INFO
        call ItoA_hex

        pop  bx
        lea  si, SI_INFO
        call ItoA_hex

        push ax
        mov ax, 0B800h         ; Видеопамять
        mov es, ax
        pop ax

        lea si, REGISTERS_INFO_STR
        lea dx , FrameStyle
        mov ah , 0Eh



		call Print_Frame

        jmp TransferControlToTimer


TransferControlToTimer:
        pop ds es si di dx cx bx ax

                        db 0eah        ; jmp 0000:0000
        old_timer_ofs   dw 0
        old_timer_seg   dw 0

        endp
;---------------------------------------------------------------------

ItoA_hex:
        mov cx, 4   ; 4 bytes in register
        add si, 3

    new_digit_itoa:
        push bx
        and bx, 000Fh

        cmp bx, 9h
        ja  bx_is_letter_itoa
        add bx, '0'
        jmp bx_is_parsed_itoa

    bx_is_letter_itoa:
        add bx, 'A' - 0Ah

    bx_is_parsed_itoa:
        mov byte ptr ds:[si], bl
        dec si

        pop bx
        sar bx, 4   ; 4 binary digits in one hex digit

    loop new_digit_itoa

        endp

Print_Frame:

    push cx
    push si
    call Level_out

    mov si, dx        ; SI указывает на массив topRow
    mov cx, [length]            ; CX = ширина рамки
    call PrintRow

                           ; Вывод средних строк
    mov cx, [height]            ; CX = высота рамки
    call PrintMiddleRows

    ; Вывод нижней строки
    ; mov si,         ; SI указывает на массив botRow
    mov cx, [length]            ; CX = ширина рамки
    call PrintRow

    pop si
    pop cx

    call PrintRegisters

    ret


PrintRegisters:
    call Level_out  ; Устанавливаем DI в начало рамки

    ; Смещаем DI на нужное место (по центру)
    add di, 80 * 2 + 2 * 2

    mov cx, 6  ; У нас 6 строк с регистрами (AX, BX, CX, DX, DI, SI)
    lea si, REGISTERS_INFO_STR  ; Загружаем начало строк

PrintRegisterLoop:
    push cx
    call PrintRegisterLine  ; Выводим одну строку
    call NewLine_For_String ; Переход на новую строку
    pop cx
    loop PrintRegisterLoop  ; Повторяем для всех 6 строк


    ret

PrintRegisterLine:
    mov cx, 9   ; Длина строки (9 символов)

PrintCharLoop:
    lodsb       ; Загружаем символ из SI (строки)
    stosw       ; Записываем символ в видеопамять
    loop PrintCharLoop  ; Повторяем для 9 символов

    ret
PrintRow:

    lodsb                   ; AL = первый символ (левый угол)
    ; mov ah, 4Eh
    stosw                   ; Запись символа и атрибута

    lodsb                   ; AL = горизонтальная линия (─)           ; CX = ширина
    sub cx, 2               ; Исключаем углы

    rep stosw               ; Заполняем линией

    lodsb                   ; AL = последний символ (правый угол)
    ; mov ah, 4Eh
    stosw                   ; Запись символа и атрибута

    call NewLine            ; Переход на новую строку
    ret

;---------------------------------------------------------------
; PrintMiddleRows - вывод средних строк рамки
; Вход: CX - высота рамки, ES:DI - начало видеопамяти
;---------------------------------------------------------------
PrintMiddleRows:

    push dx
    mov dx , si

MiddleRowLoop:
    push cx                 ; Сохраняем CX

    mov si , dx

    ; Выводим левую границу
    lodsb                   ; AL = левый вертикальный символ │
    ; mov ah, 4Eh
    stosw                   ; Запись в видеопамять

                            ; Заполняем пробелами между границами
    lodsb                   ; AL = пробел
    mov cx, [length]             ; CX = ширина
    sub cx, 2               ; Исключаем границы

    rep stosw               ; Заполняем пробелами

    ; Выводим правую границу
    lodsb                   ; AL = правый вертикальный символ │
    ; mov ah, 4Eh
    stosw                   ; Запись в видеопамять

    call NewLine            ; Переход на новую строку

    pop cx
    loop MiddleRowLoop      ; Следующая строка
    pop dx
    ret

;---------------------------------------------------------------
; NewLine - переход на следующую строку видеопамяти
;---------------------------------------------------------------
NewLine:

    push ax

    mov ax, 80
    sub ax, [length]              ; Количество пропущенных символов
    shl ax, 1                ; Умножаем на 2 (символ + атрибут)
    add di, ax               ; Смещаем DI

    pop ax

    ret

;---------------------------------------------------------------
NewLine_For_String:

    push ax

    mov ax, 80
    sub ax, 9                ; Количество пропущенных символов
    shl ax, 1                ; Умножаем на 2 (символ + атрибут)
    add di, ax               ; Смещаем DI

    pop ax

    ret
;---------------------------------------------------------------
Delay:

    push ax
    push dx
    push cx
    push si
    push di

    mov si , 0
    mov ah , 86h
    mov cx , 2
    mov dx , 50000
    int 15h

    pop di
    pop si
    pop cx
    pop dx
    pop ax

    ret

;---------------------------------------------------------------

;---------------------------------------------------------------
Level_out:

    push ax
    push bx
    push dx
    ; ---- Горизонтальное центрирование ----
    mov ax, 80            ; Ширина экрана (80 символов)
    mov bx, [length]            ; Ширина рамки
    shr ax, 1              ; 80 / 2
    shr bx, 1              ; b/2
    sub ax, bx             ; 40 - (b/2) = X-координата начала рамки
    shl ax, 1              ; Умножаем на 2 (1 символ = 2 байта)
    mov di, ax

    ; ---- Вертикальное центрирование ----
    mov cx, 25             ; Высота экрана (25 строк)
    sub cx, [height]            ; (25 - a)
    shr cx , 1
    mov ax , 160
    mul cx
    add di , ax
    pop dx
    pop bx
    pop ax

    ret

.data


height           dw 8
length           dw 13
FrameStyle       db '#-#@ @#-#'
love_string      db 'Hello$', 0  ; Строка для вывода (с символом $ в конце)




REGISTERS_INFO_STR:
            db 'ax = '
AX_INFO     db '0000'

            db 'bx = '
BX_INFO     db '0000'

            db 'cx = '
CX_INFO     db '0000'

            db 'dx = '
DX_INFO     db '0000'

            db 'di = '
DI_INFO     db '0000'

            db 'si = '
SI_INFO     db '0000'

FRAME_FLAG  db 0


EOP:
end Start
