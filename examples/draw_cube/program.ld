MEMORY
{
   ram      (rwx) : ORIGIN = 0x10000000, LENGTH = 256*1024-1024
}
__stacktop = ORIGIN(ram) + LENGTH(ram);

SECTIONS {
	.memory : {
		. = 0x000000;
		*(.init);
		*(.text);
		*(*);
		. = ALIGN(4);
		end = .;
	} >ram
}