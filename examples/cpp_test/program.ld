MEMORY
{
   ram      (rwx) : ORIGIN = 0x10000000, LENGTH = 512*1024
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

	.heap : {
		. = ALIGN(4);
		_heap_start = .;
		_end = .;
	} >ram
}