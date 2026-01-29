/* start.S */
    .section .text
    .global _start
_start:
    la sp, stack_top
    call main
hang:
    j hang

    .section .bss
    .balign 4
stack:
    .space 4096
stack_top:

