; Начальный загрузчик ядра для архитектуры x86
format Binary as "bin"
org 0x7C00
	jmp boot
; Данные начального загрузчика
align 4
label sector_per_track word at $$
label head_count byte at $$ + 2
label disk_id byte at $$ + 3
boot_msg db "MyOS boot loader. Version 0.01",13,10,0
reboot_msg db "Press any key...",13,10,0
; Вывод строки DS:SI на экран
write_str:
	push ax si
	mov ah, 0x0E
 @@:
	lodsb
	test al, al
	jz @f
	int 0x10
	jmp @b
 @@:
	pop si ax
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
	cmp byte[sector_per_track], 0xFF
	je .use_EDD
	push ax bx cx dx si
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
	pop si dx cx bx ax
	ret
 .use_EDD:
	push ax dx si
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
	pop si dx ax
	ret
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
	; Выводим приветственное сообщение
	mov si, boot_msg
	call write_str
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
	; Завершение
	jmp reboot
; Пустое пространство и сигнатура
rb 510 - ($ - $$)
db 0x55,0xAA
