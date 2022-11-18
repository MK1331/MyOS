; Начальный загрузчик ядра для архитектуры x86
format Binary as "bin"
org 0x7C00
	jmp boot
; Заголовок ListFS
align 4
fs_magic dd ?
fs_version dd ?
fs_flags dd ?
fs_base dq ?
fs_size dq ?
fs_map_base dq ?
fs_map_size dq ?
fs_first_file dq ?
fs_uid dq ?
fs_block_size dd ?
; Заголовок файла
virtual at 0x800
f_info:
	f_name rb 256
	f_next dq ?
	f_prev dq ?
	f_parent dq ?
	f_flags dq ?
	f_data dq ?
	f_size dq ?
	f_ctime dq ?
	f_mtime dq ?
	f_atime dq ?
end virtual
; Данные начального загрузчика
label sector_per_track word at $$
label head_count byte at $$ + 2
label disk_id byte at $$ + 3
reboot_msg db "Press any key...",13,10,0
boot_file_name db "boot.bin",0
; Вывод строки DS:SI на экран
write_str:
	push si
	mov ah, 0x0E
 @@:
	lodsb
	test al, al
	jz @f
	int 0x10
	jmp @b
 @@:
	pop si
	ret
; Критическая ошибка
error:
	pop si
	call write_str
; Перезагрузка
reboot:
	mov si, reboot_msg
	call write_str
	xor ah, ah
	int 0x16
	jmp 0xFFFF:0
; Загрузка сектора DX:AX в буфер ES:DI
load_sector:
	push dx
	add ax, word[fs_base]
	adc dx, word[fs_base + 2]
	cmp byte[sector_per_track], 0xFF
	je .use_EDD
	push bx cx si
	div [sector_per_track]
	mov cl, dl
	inc cl
	div [head_count]
	mov dh, ah
	mov ch, al
	mov dl, [disk_id]
	mov bx, di
	mov al, 1
	mov si, 3
 @@:
	mov ah, 2
	int 0x13
	jnc @f
	xor ah, ah
	int 0x13
	dec si
	jnz @b
 .error:
	call error
	db "DISK ERROR",13,10,0
 @@:
	pop si cx bx dx
	ret
 .use_EDD:
	push si
	mov byte[0x600], 0x10
	mov byte[0x601], 0
	mov word[0x602], 1
	mov [0x604], di
	push es
	pop word[0x606]
	mov [0x608], ax
	mov [0x60A], dx
	mov word[0x60C], 0
	mov word[0x60E], 0
	mov ah, 0x42
	mov dl, [disk_id]
	mov si, 0x600
	int 0x13
	jc .error
	pop si dx
	ret
; Поиск файла с именем DS:SI в каталоге DX:AX
find_file:
	push cx dx di
 .find:
	cmp ax, -1
	jne @f
	cmp dx, -1
	jne @f
 .not_found:
	call error
	db "NOT FOUND",13,10,0
 @@:
	mov di, f_info
	call load_sector
	push di
	mov cx, 0xFFFF
	xor al, al
	repne scasb
	neg cx
	dec cx
	pop di
	push si
	repe cmpsb
	pop si
	je .found
	mov ax, word[f_next]
	mov dx, word[f_next + 2]
	jmp .find
 .found:
	pop di dx cx
	ret
; Загрузка текущего файла в память по адресу BX:0. Количество загруженных секторов возвращается в AX
load_file_data:
	push bx cx dx si di
	mov ax, word[f_data]
	mov dx, word[f_data + 2]
 .load_list:
	cmp ax, -1
	jne @f
	cmp dx, -1
	jne @f
 .file_end:
	pop di si dx cx
	mov ax, bx
	pop bx
	sub ax, bx
	shr ax, 9 - 4
	ret
 @@:
	mov di, 0x8000 / 16
	call load_sector
	mov si, di
	mov cx, 512 / 8 - 1
 .load_sector:
	lodsw
	mov dx, [si]
	add si, 6
	cmp ax, -1
	jne @f
	cmp dx, -1
	je .file_end	
 @@:
	push es
	mov es, bx
	xor di, di
	call load_sector
	add bx, 0x200 / 16
	pop es
	loop .load_sector
	lodsw
	mov dx, [si]
	jmp .load_list
; Точка входа в начальный загрузчик
boot:
	; Настроим сегментные регистры
	jmp 0:@f
 @@:
	mov ax, cs
	mov ds, ax
	mov es, ax
	; Настроим стек
	mov ss, ax
	mov sp, $$
	; Разрешим прерывания
	sti
	; Запомним номер загрузочного диска
	mov [disk_id], dl
	; Определим параметры загрузочного диска
	mov ah, 0x41
	mov bx, 0x55AA
	int 0x13
	jc @f
	mov byte[sector_per_track], 0xFF
	jmp .disk_detected
 @@:
	mov ah, 0x08
	xor di, di
	push es
	int 0x13
	pop es
	jc load_sector.error
	inc dh
	mov [head_count], dh
	and cx, 111111b
	mov [sector_per_track], cx
 .disk_detected:
	; Загрузим продолжение начального загрузчика
	mov si, boot_file_name
	mov ax, word[fs_first_file]
	mov dx, word[fs_first_file + 2]
	call find_file
	mov bx, 0x7E00 / 16
	call load_file_data
	; Переходим на продолжение
	jmp boot2
; Пустое пространство и сигнатура
rb 510 - ($ - $$)
db 0x55,0xAA
; Дополнительные данные загрузчика
load_msg_preffix db "Loading '",0
load_msg_suffix db "'...",13,10,0
ok_msg db "OK",13,10,0
config_file_name db "boot.cfg",0
start16_msg db "Starting 16 bit kernel...",13,10,0
start32_msg db "Starting 32 bit kernel...",13,10,0
start64_msg db "Starting 64 bit kernel...",13,10,0
; Разбиение строки DS:SI по символу слеша
split_file_name:
	push si
 @@:
	lodsb
	cmp al, "/"
	je @f
	test al, al
	jz @f
	jmp @b
 @@:
	mov byte[si - 1], 0
	mov ax, si
	pop si
	ret
; Загрузка файла с именем DS:SI в буфер BX:0. Размер файла в секторах возвращается в AX
load_file:
	push si
	mov si, load_msg_preffix
	call write_str
	pop si
	call write_str
	push si
	mov si, load_msg_suffix
	call write_str
	pop si
	push si bp
	mov dx, word[fs_first_file + 2]
	mov ax, word[fs_first_file]
 @@:
	push ax
	call split_file_name
	mov bp, ax
	pop ax
	call find_file
	test byte[f_flags], 1
	jz @f
	mov si, bp
	mov dx, word[f_data + 2]
	mov ax, word[f_data]
	jmp @b	
 @@:
	call load_file_data
	mov si, ok_msg
	call write_str
	pop bp si
	ret
; Продолжение начального загрузчика
boot2:
	; Загрузим конфигурационный файл загрузчика
	mov si, config_file_name
	mov bx, 0x1000 / 16
	call load_file
	; Выполним загрузочный скрипт
	mov bx, 0x9000 / 16
	mov bp, 0x6000
	mov dx, 0x1000
 .parse_line:
	mov si, dx
 .parse_char:
	lodsb
	test al, al
	jz .config_end
	cmp al, 10
	je .run_command
	cmp al, 13
	je .run_command
	jmp .parse_char
 .run_command:
	mov byte[si - 1], 0
	xchg dx, si
	cmp byte[si], 0
	je .parse_line ; Пустая строка
	cmp byte[si], "#"
	je .parse_line ; Комментарий
	cmp byte[si], "L"
	je .load_file ; Загрузка файла
	cmp byte[si], "S"
	je .start ; Запуск ядра
	; Неизвестная команда
	mov al, [si]
	mov [.cmd], al
	call error
	db "Unknown boot script command '"
	.cmd db ?
	db "'!",13,10,0
 .config_end: ; При правильном конфигурационном файле мы не должны сюда попасть
	; Завершение
	jmp reboot
; Загрузка файла
 .load_file:
	push dx
	inc si
	call load_file
	push ax
	mov cx, 512
	mul cx
	mov word[bp + 8], ax
	mov word[bp + 10], dx
	mov word[bp + 12], 0
	mov word[bp + 14], 0
	mov ax, bx
	mov cx, 16
	mul cx
	mov word[bp], ax
	mov word[bp + 2], dx
	mov word[bp + 4], 0
	mov word[bp + 6], 0
	pop ax
	shr ax, 9 - 4
	add bx, ax
	add bp, 16
	pop dx
	jmp .parse_line
; Запуск ядра
 .start:
	; Проверим, что загружен хотя бы один файл
	cmp bx, 0x9000 / 16
	ja @f
	call error
	db "NO KERNEL LOADED",13,10,0	
 @@:
	; Заполняем последний элемент списка файлов
	xor ax, ax
	mov cx, 16
	mov di, bp
	rep stosw
	; Переходим к процедуре инициализации ядра для нужной разрядности
	inc si
	cmp word[si], "16"
	je .start16
	cmp word[si], "32"
	je .start32
	cmp word[si], "64"
	je .start64
	; Неизвестная рязрядность ядра
	call error
	db "Invalid start command argument",13,10,0
; Запуск 16-разрядного ядра
 .start16:
	mov si, start16_msg
	mov bx, 0x6000
	mov dl, [disk_id]
	jmp 0x9000
; Запуск 32-разрядного ядра
 .start32:
	mov si, start32_msg
	call write_str
	;
	jmp reboot 
; Запуск 64-разрядного ядра
 .start64:
	; Выводим уведомление о запуске 64-битного ядра
	mov si, start64_msg
	call write_str
	;
	jmp reboot 
