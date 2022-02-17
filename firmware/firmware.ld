MEMORY
{
   ram      (rwx) : ORIGIN = 0x00000000, LENGTH = 3192
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