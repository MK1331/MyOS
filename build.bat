md bin
md disk
md images
c:\fasm\fasm.exe boot.asm ./bin/boot.bios.bin
d:\mingw\bin\gcc.exe make_listfs.c -o ./bin/make_listfs.exe
dd if=bin/boot.bios.bin of=bin/boot_sector.bin bs=512 count=1
dd if=bin/boot.bios.bin of=disk/boot.bin bs=1 skip=512
.\bin\make_listfs.exe of=./images/disk.img bs=512 size=2880 boot=bin/boot_sector.bin src=./disk
