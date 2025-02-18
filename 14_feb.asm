.model tiny
.code
org 100h

start:

    mov si, 81h           ; Адрес командной строки в PSP
    call SkipSpaces       ; Пропуск пробелов
    call ConvertStringToInt      ; Читаем ширину (b)
    mov [length], ax

    call SkipSpaces       ; Пропуск пробелов
    call ConvertStringToInt      ; Читаем высоту (a)
    mov [height], ax

    call SkipSpaces       ; Пропуск пробелов
    call ConvertHexStringToInt     ; Читаем цвет
    ; в AH лежит атрибут

    call SkipSpaces
    call GetFrameStyle

    call CopyString


    ; в DX лежит указатель на начало стиля рамки
    ; SI указывает на начало строки для вывода в рамке
    ; в AH лежит атрбут цвета
    ; в [length] , [height] длина и высота рамки


    ; mov si , dx


    push ax
    mov ax, 0B800h         ; Видеопамять
    mov es, ax
    pop ax

    ; mov ah, 01011011b          ; Атрибут цвета RUSSSSSS
    ; mov ax , 0FFFFh

    push ax
    push dx
    mov ax , [length]
    xor ah , ah
    xor dx , dx
    mov cx , 6
    div cx
    mov bx , ax

    mov ax , [length]  ; ax = конечная ширина
    sub ax, bx         ; ax = разница (сколько надо прибавить)
    xor ah, ah
    mov dx, 0
    mov cx, 6
    div cx             ; delta = разница / 6
    mov si, ax         ; Сохраняем шаг увеличения
    mov di, dx         ; Сохраняем остаток
    pop dx
    pop ax

    mov cx, 6

    call Zoom_Frame


    call Print_Text

    ; Завершение программы
    mov ah, 4Ch
    mov al, 00h
    int 21h

Zoom_Frame:

    push cx
    push si
    push di

    call Level_out

    mov si, dx        ; SI указывает на массив topRow
    mov cx, bx            ; CX = ширина рамки
    call PrintRow

                           ; Вывод средних строк
    mov cx, [height]            ; CX = высота рамки
    call PrintMiddleRows

    ; Вывод нижней строки
    ; mov si,         ; SI указывает на массив botRow
    mov cx, bx            ; CX = ширина рамки
    call PrintRow

    call Delay

    pop di
    cmp di, 0        ; Если есть остаток
    jz no_remainder
    add bx, 1        ; Увеличиваем ширину на 1 (учитываем остаток)
    dec di           ; Уменьшаем счётчик оставшихся итераций с остатком

no_remainder:
    pop si
    add bx, si       ; Увеличиваем ширину рамки на delta

    pop cx
    dec cx
    jnz Zoom_Frame

    ret

Print_Text:

    xor di ,di
    push si

    lea si , love_string

    call Calculate_Offset_For_String
    call Calculate_Length_String
    ; mov ah, DBh

Print_Text_Loop:

    lodsb
    stosw
    loop Print_Text_Loop

    pop si

    ret

Calculate_Offset_For_String:

    push ax
    push bx
    push cx
    push dx

    call Level_out
    call Calculate_Length_String  ; Получаем длину строки в CX

    ; ---- Горизонтальное центрирование ----
    mov ax, bx       ; Ширина рамки
    sub ax, cx        ; (b - длина строки)
    shr ax, 1
    shl ax, 1
    add di, ax        ; Смещаем DI на центр рамки

    ; ---- Вертикальное центрирование ----
    mov ax, [height]       ; Высота рамки
    shr ax, 1
    mov bx, 80 * 2
    mul bx            ; ax = (a / 2) * 160
    add di, ax        ; Смещаем DI вниз в центр рамки

    pop dx
    pop cx
    pop bx
    pop ax

    ret

Calculate_Length_String:

    push si   ; Сохраняем SI
    push ax   ; Сохраняем AX

    lea si, love_string
    xor cx, cx  ; Обнуляем счётчик

Find_Length_Loop:

    lodsb        ; Загружаем символ в AL
    test al, al  ; Проверяем, не конец ли строки (\0)
    jz Done_3      ; Если да, выходим
    inc cx       ; Увеличиваем счётчик
    jmp Find_Length_Loop  ; Повторяем

Done_3:

    pop ax
    pop si
    ret



;---------------------------------------------------------------
; PrintRow - вывод строки (угол + линия + угол) через stosw
; Вход: SI - адрес массива символов, CX - ширина строки, ES:DI - начало видеопамяти
;---------------------------------------------------------------
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
    mov cx, bx             ; CX = ширина
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
    sub ax, bx              ; Количество пропущенных символов
    shl ax, 1                ; Умножаем на 2 (символ + атрибут)
    add di, ax               ; Смещаем DI

    pop ax

    ret

;---------------------------------------------------------------

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
    mov ax, 80             ; Ширина экрана (80 символов)
    ; mov bx, [length]            ; Ширина рамки
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






GetFrameStyle:
    push ax
    xor ah , ah
    lodsb
    cmp al, '0'
    je  GetCustomStyle
    push si
    cmp al, '1'
    jl  End_GetFrameStyle
    cmp al, '5'
    jg  End_GetFrameStyle


    sub al, '1'
    ; mov bl, al
    lea si, [frameStyles]
    mov cx, 9
    mul cx
    add si, ax

    mov dx , si         ; SAVVVEEEE

    pop si
    inc si
    call SkipSpaces
    inc si              ; После этого SI указывает на начло строки для вывода в рамке


    jmp End_GetFrameStyle
;
GetCustomStyle:
    ; В случае числа 0, указываем на стиль, который ввёл пользователь
    ; Строка в командной строке после числа 0 - это стиль рамки в 9 символах.
    call SkipSpaces
    inc si              ; Пропускаем пробел или число
    ; Здесь si уже указывает на первый символ стиля рамки, введённого вручную.
    mov dx , si
    add si , 9 + 1
    call SkipSpaces
    inc si              ;После этого SI указывает на начло строки для вывода в рамке

End_GetFrameStyle:
    ; Теперь DX указывает на нужный стиль рамки (либо из массива, либо введённый вручную)
    ;а SI указывает на начала строки для вывода в рамке
    pop ax

    ret


CopyString:
    lea di, love_string  ; Загружаем адрес love_string в DI

CopyLoop:
    mov al, [si]          ; Загружаем текущий символ
    cmp al, '$'           ; Проверяем, конец ли строки (закрывающая кавычка)
    je AddNullTerminator  ; Если кавычка, ставим 0 и выходим
    mov [di], al          ; Копируем символ в love_string
    inc si                ; Переход к следующему символу
    inc di                ; Переход к следующему месту в love_string
    jmp CopyLoop          ; Повторяем цикл

AddNullTerminator:
    mov  [di], 0      ; Записываем нулевой символ в конец строки
    ret
; ---- Вспомогательные функции ----

SkipSpaces:
    mov al, [si]        ; Загружаем текущий символ

SkipLoop:
    cmp al, ' '         ; Проверяем пробел (' ')
    je  NextChar        ; Если пробел, переходим к следующему символу
    cmp al, 9           ; Проверяем табуляцию (ASCII 9)
    je  NextChar        ; Если табуляция, тоже пропускаем
    ret                 ; Если символ не пробел и не табуляция, возвращаемся

NextChar:
    inc si              ; Переход к следующему символу
    mov al, [si]        ; Загружаем следующий символ
    jmp SkipLoop        ; Проверяем его снова

SkipQuotes:
    lodsb                      ; Загружаем следующий символ
    cmp al, '"'                ; Сравниваем с кавычкой
    je SkipQuotes              ; Если это кавычка, пропускаем её
    dec si                     ; Возвращаем указатель назад, если это не кавычка
    ret

; Функция: ConvertStringToInt
; Преобразует строку в число
; Вход: DS:SI - указатель на строку
; Выход: AX - преобразованное число

ConvertStringToInt:
    xor ax, ax            ; AX = 0 (очищаем)
    xor bx, bx            ; BX = 0 (инициализируем для результата)

ConvertLoop:
    mov al, [si]       ; Загружаем текущий символ
    cmp al, '0'           ; Проверяем, что >= '0'
    jl  End_ConvertStringToInt             ; Если меньше, завершаем
    cmp al, '9'           ; Проверяем, что <= '9'
    jg  End_ConvertStringToInt             ; Если больше, завершаем
    sub al, '0'           ; Преобразуем символ в число (ASCII → int)
    mov ah, [si + 1]      ; Загружаем следующий символ
    cmp ah, '0'           ; Проверяем, что это цифра
    jl  LastDigit         ; Если нет, завершаем обработку
    cmp ah, '9'
    jg  LastDigit         ; Если нет, завершаем обработку
    mov cx, 10         ; Загружаем множитель 10
    mul cx             ; AX = AX * 10
    add bx, ax         ; BX = BX + новая цифра
    inc si                ; Следующий символ
    jmp ConvertLoop       ; Повторяем

LastDigit:
    xor ah  , ah
    add bx, ax
    inc si

End_ConvertStringToInt:
    mov ax, bx            ; Переносим результат в AX
    ret


; Функция ConvertHexStringToInt
; Преобразует шестнадцатеричную строку в число
; Вход: DS:SI - указатель на строку
; Выход: AX - преобразованное число
ConvertHexStringToInt:
    xor ax, ax         ; Очищаем AX (будет хранить результат)
    xor bx, bx         ; Очищаем BX (будет временно хранить результат)

ConvertHexLoop:
    mov al, [si]       ; Загружаем текущий символ
    cmp al, 0          ; Проверяем конец строки (нулевой байт)
    je End_ConvertHexStringToInt           ; Если конец строки, выходим

    ; Проверка на цифры '0'-'9'
    cmp al, '0'
    jl  End_ConvertHexStringToInt          ; Если меньше '0', завершаем
    cmp al, '9'
    jg  CheckLetter     ; Если больше '9', проверяем буквы 'A'-'F'
    sub al, '0'         ; Преобразуем ASCII-цифру в число (0-9)
    jmp ProcessDigit    ; Переходим к обработке

CheckLetter:
    cmp al, 'A'
    jl  End_ConvertHexStringToInt          ; Если символ меньше 'A', это не HEX-цифра
    cmp al, 'F'
    jg  End_ConvertHexStringToInt          ; Если больше 'F', тоже не HEX-цифра
    sub al, 'A' - 10    ; Преобразуем 'A'-'F' в 10-15

ProcessDigit:
    mov cx, 16          ; Загружаем множитель 16
    mov dx, bx          ; Сохраняем текущее значение результата в dx
    shl bx, 4           ; Сдвигаем bx влево на 4 бита (умножаем на 16)
    add bx, ax          ; Добавляем к результату цифру
    inc si              ; Переход к следующему символу
    jmp ConvertHexLoop  ; Повторяем цикл

End_ConvertHexStringToInt:
    mov ah, bl          ; Переносим результат в AH (вместо AX)
    ret




.data
height           dw 6
length           dw 60
numstyle         dw 1
addr_mas_style   dw 1
frameStyles      db '#########', '+++++++++', '=========', '*********', '@@@@@@@@@'
love_string      db 'Hello$', 0  ; Строка для вывода (с символом $ в конце)

end start
