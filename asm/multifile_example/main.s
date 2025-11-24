.section .text._start
.globl _start
_start:
    li x8, 1000000
    addi x1, x0, 5
    jal x2, sub
    addi x1, x1, 10
