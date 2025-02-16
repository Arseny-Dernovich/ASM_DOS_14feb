.model tiny
.code
org 100h

start:
    mov si, 81h           ; Адрес командной строки в PSP
    call SkipSpaces       ; Пропуск пробелов
    call ConvertStringToInt      ; Читаем ширину (b)
    mov [b], ax

    call SkipSpaces       ; Пропуск пробелов
    call ConvertStringToInt      ; Читаем высоту (a)
    mov [a], ax

    call SkipSpaces       ; Пропуск пробелов
    call ConvertHexStringToInt     ; Читаем цвет
    ; в AH лежит атрибут

    call SkipSpaces
    call GetFrameStyle

    call CopyString

    mov ah, 4Ch
    int 21h

GetFrameStyle:
    push ax
    push si
    xor ah , ah
    lodsb       ; Загружаем число стиля
    cmp al, '0'        ; Проверяем, если 0
    je  GetCustomStyle  ; Если 0, читаем стиль вручную
    cmp al, '1'        ; Если от 1 до 5
    jl  Done_2           ; Если меньше 1 (неправильный ввод), выходим
    cmp al, '5'        ; Проверяем, если больше 5
    jg  Done_2           ; Если больше 5, выходим

    ; Загружаем стиль рамки из массива, который у тебя заранее подготовлен
    sub al, '1'         ; Преобразуем 1..5 в 0..4
    ; mov bl, al          ; Сохраняем индекс стиля в BL
    lea si, [frameStyles]  ; Адрес массива стилей рамки
    mov cx, 9           ; Длина одного стиля рамки (9 символов)
    mul cx              ; Умножаем индекс на 9
    add si, ax          ; Получаем адрес стиля (si + индекс * 9)

    mov dx , si         ; SAVVVEEEE

    pop si
    inc si
    call SkipSpaces
    inc si              ; После этого SI указывает на начло строки для вывода в рамке

    pop ax

    jmp Done_2
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
    inc si              ;После этого SI указывает на начало строки для вывода в рамке

Done_2:
    ; Теперь DX указывает на нужный стиль рамки (либо из массива, либо введённый вручную)
    ;а SI указывает на начала строки для вывода в рамке

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
    jl  Done              ; Если меньше, завершаем
    cmp al, '9'           ; Проверяем, что <= '9'
    jg  Done              ; Если больше, завершаем
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

Done:
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
    je Done_1           ; Если конец строки, выходим

    ; Проверка на цифры '0'-'9'
    cmp al, '0'
    jl  Done_1          ; Если меньше '0', завершаем
    cmp al, '9'
    jg  CheckLetter     ; Если больше '9', проверяем буквы 'A'-'F'
    sub al, '0'         ; Преобразуем ASCII-цифру в число (0-9)
    jmp ProcessDigit    ; Переходим к обработке

CheckLetter:
    cmp al, 'A'
    jl  Done_1          ; Если символ меньше 'A', это не HEX-цифра
    cmp al, 'F'
    jg  Done_1          ; Если больше 'F', тоже не HEX-цифра
    sub al, 'A' - 10    ; Преобразуем 'A'-'F' в 10-15

ProcessDigit:
    mov cx, 16          ; Загружаем множитель 16
    mov dx, bx          ; Сохраняем текущее значение результата в dx
    shl bx, 4           ; Сдвигаем bx влево на 4 бита (умножаем на 16)
    add bx, ax          ; Добавляем к результату цифру
    inc si              ; Переход к следующему символу
    jmp ConvertHexLoop  ; Повторяем цикл

Done_1:
    mov ah, bl          ; Переносим результат в AH (вместо AX)
    ret


; ---- Данные ----

a           dw 6
b           dw 60
numstyle    dw 1
addr_mas_style dw 1


frameStyles db '#########', '+++++++++', '=========', '*********', '@@@@@@@@@'
love_string db 'Hello$', 0  ; Строка для вывода (с символом $ в конце)

end start
