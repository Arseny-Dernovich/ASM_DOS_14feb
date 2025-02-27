.model tiny
.386

.code

org 100h



REGISTERS_INFO_KEY  equ 0Fh     ; Tab  scan code
LEN_TERMINAL        equ 80
Count_Registers     equ 12





Start:
        xor ax , ax
        mov es , ax
        mov bx , 09h * 4

        mov ax , es:[bx]
        mov old09ofs , ax
        mov ax , es:[bx + 2]
        mov old09seg , ax

        cli
        mov word ptr es:[bx] , offset Intercept_Keyboard
        mov ax , cs
        mov es:[bx + 2] , ax
        sti


        xor ax , ax
        mov es , ax
        mov bx , 08h * 4

        mov ax , es:[bx]
        mov old_timer_ofs , ax
        mov ax , es:[bx + 2]
        mov old_timer_seg , ax

        cli
        mov word ptr es:[bx] , offset Intercept_Timer
        mov ax , cs
        mov es:[bx + 2] , ax
        sti


        int 09h

        mov ax , 3100h
        mov dx , offset EOP
        shr dx , 4
        inc dx
        int 21h


;-------------------------------------------------------------------------------------
; Intercept_Keyboard - перехватчик прерывания 09h (клавиатуры).
; Проверяет , нажата ли клавиша REGISTERS_INFO_KEY (Tab).
; Если да , то переключает FRAME_FLAG.
;
; Вход:  es = VIDEOSEG
; Выход: нет
; Разрушает: нет
;-------------------------------------------------------------------------------------
Intercept_Keyboard proc
        push ax bx cx dx di si es ds
        push cs
        pop ds

        in  al , 60h
        cmp al , REGISTERS_INFO_KEY
        jne Transfer_Control_To_Int_09h

        mov al , FRAME_FLAG
        xor al , 1
        mov byte ptr FRAME_FLAG , al

Transfer_Control_To_Int_09h:
        pop ds es si di dx cx bx ax

                    db 0eah        ; jmp 0000:0000
        old09ofs    dw 0
        old09seg    dw 0
endp

;-------------------------------------------------------------------------------------
; Intercept_Timer - перехватчик таймера (прерывание 08h).
; Если FRAME_FLAG = 1 , то рисует рамку с регистрами.
;
; Вход:  es = VIDEOSEG
; Выход: нет
; Разрушает: нет
;-------------------------------------------------------------------------------------
Intercept_Timer proc
        push ax bx cx dx di si es ds
        push cs
        pop ds

        mov al , FRAME_FLAG
        cmp al , 1
        jne Transfer_Control_To_Timer

        push cs
        push ss
        push es
        push ds
        push sp
        push bp
        push si
        push di
        push dx
        push cx
        push bx
        push ax

        cld

        pop  bx
        lea  si , AX_INFO
        call Itoa_Hex

        pop  bx
        lea  si , BX_INFO
        call Itoa_Hex

        pop  bx
        lea  si , CX_INFO
        call Itoa_Hex

        pop  bx
        lea  si , DX_INFO
        call Itoa_Hex

        pop  bx
        lea  si , DI_INFO
        call Itoa_Hex

        pop  bx
        lea  si , SI_INFO
        call Itoa_Hex

        pop  bx
        lea  si , BP_INFO
        call Itoa_Hex

        pop  bx
        lea  si , SP_INFO
        call Itoa_Hex

        pop  bx
        lea  si , DS_INFO
        call Itoa_Hex

        pop  bx
        lea  si , ES_INFO
        call Itoa_Hex

        pop  bx
        lea  si , SS_INFO
        call Itoa_Hex

        pop bx
        lea si , CS_INFO
        call Itoa_Hex

        push ax
        mov ax , 0B800h
        mov es , ax
        pop ax

        lea si , REGISTERS_INFO_STR
        lea dx  , Frame_Style
        mov ah  , 0Eh
        call Print_Frame

Transfer_Control_To_Timer:
        pop ds es si di dx cx bx ax

                    db 0eah
        old_timer_ofs   dw 0
        old_timer_seg   dw 0
endp


;-------------------------------------------------------------------------------------
; Itoa_Hex - конвертирует число в шестнадцатеричную строку.
;
; Вход:  bx - число для конвертации
;        si - адрес строки для записи
; Выход: строка в si будет содержать шестнадцатеричное представление числа
; Разрушает: cx , si
;-------------------------------------------------------------------------------------
Itoa_Hex proc
        mov cx , 4
        add si , 3

    New_Digit_Itoa:
        push bx
        and bx , 000Fh

        cmp bx , 9h
        ja  BX_Is_Letter_Itoa
        add bx , '0'
        jmp BX_Is_Parsed_Itoa

    bx_is_letter_itoa:
        add bx , 'A' - 0Ah

    bx_is_parsed_itoa:
        mov byte ptr ds:[si] , bl
        dec si

        pop bx
        sar bx , 4

    loop New_Digit_Itoa
endp

;-------------------------------------------------------------------------------------
; Print_Frame - рисует рамку и внутри неё значения регистров.
;
; Вход: нет
; Выход: нет
; Разрушает: si , di , cx
;-------------------------------------------------------------------------------------
Print_Frame proc
    push cx
    push si
    call Level_out

    mov si , dx
    mov cx , [length]
    call Print_Row

    mov cx , [height]
    call Print_Middle_Rows

    mov cx , [length]
    call Print_Row

    pop si
    pop cx
    call Print_Registers
    ret
endp

;-------------------------------------------------------------------------------------
; PrintRegisters - выводит значения регистров внутри рамки.
;
; Вход: нет
; Выход: нет
; Разрушает: si , di , cx
;-------------------------------------------------------------------------------------
Print_Registers proc
    call Level_out

    add di , 80 * 2 + 2 * 2
    mov cx , Count_Registers
    lea si , REGISTERS_INFO_STR

Print_Register_Loop:
    push cx
    call Print_Register_Line
    call NewLine_For_String
    pop cx
    loop Print_Register_Loop

    ret
endp

;-------------------------------------------------------------------------------------
; Print_Register_Line - выводит строку с одним регистром.
;
; Вход: si - строка для вывода
; Выход: нет
; Разрушает: cx
;-------------------------------------------------------------------------------------
Print_Register_Line proc
    mov cx , 9

Print_Char_Loop:
    lodsb
    stosw
    loop Print_Char_Loop

    ret
endp
Print_Row:

    lodsb                   ; AL = первый символ (левый угол)
    ; mov ah , 4Eh
    stosw                   ; Запись символа и атрибута

    lodsb                   ; AL = горизонтальная линия (─)           ; CX = ширина
    sub cx , 2               ; Исключаем углы

    rep stosw               ; Заполняем линией

    lodsb                   ; AL = последний символ (правый угол)
    ; mov ah , 4Eh
    stosw                   ; Запись символа и атрибута

    call NewLine            ; Переход на новую строку
    ret

;---------------------------------------------------------------
; Print_Middle_Rows - вывод средних строк рамки
; Вход: CX - высота рамки , ES:DI - начало видеопамяти
;---------------------------------------------------------------
Print_Middle_Rows:

    push dx
    mov dx  , si

Middle_Row_Loop:
    push cx                 ; Сохраняем CX

    mov si  , dx

    ; Выводим левую границу
    lodsb                   ; AL = левый вертикальный символ │
    ; mov ah , 4Eh
    stosw                   ; Запись в видеопамять

                            ; Заполняем пробелами между границами
    lodsb                   ; AL = пробел
    mov cx , [length]             ; CX = ширина
    sub cx , 2               ; Исключаем границы

    rep stosw               ; Заполняем пробелами

    ; Выводим правую границу
    lodsb                   ; AL = правый вертикальный символ │
    ; mov ah , 4Eh
    stosw                   ; Запись в видеопамять

    call NewLine            ; Переход на новую строку

    pop cx
    loop Middle_Row_Loop      ; Следующая строка
    pop dx
    ret

;---------------------------------------------------------------
; NewLine - переход на следующую строку видеопамяти
;---------------------------------------------------------------
NewLine:

    push ax

    mov ax , 80
    sub ax , [length]              ; Количество пропущенных символов
    shl ax , 1                ; Умножаем на 2 (символ + атрибут)
    add di , ax               ; Смещаем DI

    pop ax

    ret

;---------------------------------------------------------------
NewLine_For_String:

    push ax

    mov ax , 80
    sub ax , 9                ; Количество пропущенных символов
    shl ax , 1                ; Умножаем на 2 (символ + атрибут)
    add di , ax               ; Смещаем DI

    pop ax

    ret
;---------------------------------------------------------------
Delay:

    push ax
    push dx
    push cx
    push si
    push di

    mov si  , 0
    mov ah  , 86h
    mov cx  , 2
    mov dx  , 50000
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
    mov ax , LEN_TERMINAL            ; Ширина экрана (80 символов)
    mov bx , [length]            ; Ширина рамки
    shr ax , 1              ; 80 / 2
    shr bx , 1              ; b/2
    sub ax , bx             ; 40 - (b/2) = X-координата начала рамки
    shl ax , 1              ; Умножаем на 2 (1 символ = 2 байта)
    mov di , ax

    ; ---- Вертикальное центрирование ----
    mov cx , 25             ; Высота экрана (25 строк)
    sub cx , [height]            ; (25 - a)
    shr cx  , 1
    mov ax  , 160
    mul cx
    add di  , ax
    pop dx
    pop bx
    pop ax

    ret

.data


height           dw 14
length           dw 13
Frame_Style      db '�ͻ� ��ͼ'
love_string      db 'Hello$' , 0




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

            db 'bp = '
BP_INFO     db '0000'

            db 'sp = '
SP_INFO     db '0000'

            db 'ds = '
DS_INFO     db '0000'

            db 'es = '
ES_INFO     db '0000'

            db 'ss = '
SS_INFO     db '0000'

            db 'cs = '
CS_INFO     db '0000'

            db 'ip = '
IP_INFO     db '0000'



FRAME_FLAG  db 0


EOP:
end Start
