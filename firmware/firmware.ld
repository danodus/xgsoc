MEMORY
{
   rom      (rx) : ORIGIN = 0x00000000, LENGTH = 4096
}
__stacktop = ORIGIN(rom) + LENGTH(rom);

SECTIONS {
	.memory : {
		. = 0x000000;
		*(.init);
		*(.text);
		*(*);
		. = ALIGN(4);
		end = .;
	} >rom
}