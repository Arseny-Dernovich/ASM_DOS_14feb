#include "My_features.h"
#include "TXLib.h"

//
// int main ()
// {
//     txCreateWindow (1000 , 600);
//
//     printf (" %d " , txPlayVideo (580 , 330 , 0 , 0 , "video_2025-03-03_22-15-01.mp4" , 0 , 7));
//
//     return 0;
//
//
// }


#include <stdio.h>
#include <stdlib.h>

void modify_byte_at_offset(const char *input_file, const char *output_file, long offset, unsigned char new_value) {
    FILE *in = fopen(input_file, "rb");
    if (!in) {
        perror("Ошибка открытия входного файла");
        return;
    }

    FILE *out = fopen(output_file, "wb");
    if (!out) {
        perror("Ошибка создания выходного файла");
        fclose(in);
        return;
    }

    int byte;
    long pos = 0;
    while ((byte = fgetc(in)) != EOF) {
        if (pos == offset) {
            byte = new_value; // Заменяем нужный байт
        }
        fputc(byte, out);
        pos++;
    }

    fclose(in);
    fclose(out);
    printf("Файл '%s' создан с изменениями (байт на 0x%lX заменён).\n", output_file, offset);
}

int main() {
    const char *original = "CRACK.com";   // Исходный файл
    const char *modified = "HACK_CRACK.com";   // Новый файл с изменённым байтом
    long offset = 0x14;                     // Адрес нужного байта (0114h)
    unsigned char new_value = 0x74;          // Заменяем JNE (0x75) на JE (0x74)

    modify_byte_at_offset(original, modified, offset, new_value);
    return 0;
}
