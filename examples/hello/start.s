    .section .text
    .global _start
    .global main

_start:
    jal ra,main
loop:
    j loop
