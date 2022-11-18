org 0x7C00
	jmp word boot
; Данные начального загрузчика
label disk_id byte at $$
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
	; Выводим приветственное сообщение
	mov si, boot_msg
	call write_str
	; Завершение
	jmp reboot
; Пустое пространство и сигнатура
rb 510 - ($ - $$)
db 0x55,0xAA