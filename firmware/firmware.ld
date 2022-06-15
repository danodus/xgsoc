MEMORY
{
   rom      (rx) : ORIGIN = 0x00000000, LENGTH = 8192
}
/* RAM region is 0x10000000 - 0x1FFFFFFF */
__stacktop = 0x20000000;
SECTIONS {
	.memory : {
		. = 0x00000000;
		*(.init);
		*(.text);
		*(*);
		. = ALIGN(4);
		end = .;
	} >rom
}