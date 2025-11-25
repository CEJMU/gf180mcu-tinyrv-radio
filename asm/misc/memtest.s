.section .text._start
.globl _start
_start:
    li x1, 0x1000002
    li x5, 97
    sw x5, 0(x1)

    li x2, 0b100000000000000100000000
    li x3, 0b000000000000000100000000
    li x4, 0xDEADBEEF

    sw x4, 0(x2)
    lw x5, 0(x3)

    sw x5, 0(x1)
    srli x5, x5, 8
    sw x5, 0(x1)
    srli x5, x5, 8
    sw x5, 0(x1)
    srli x5, x5, 8
    sw x5, 0(x1)
loop:
    j loop
