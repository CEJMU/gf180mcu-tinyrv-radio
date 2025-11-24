.section .text._start
.globl _start
_start:
    li x1, 160
    li x2, 65535
    slli x2, x2, 1

    // lw test
    sw x2, 0(x1)
    lw x3, 0(x1)
    lb x4, 0(x1)
    lbu x5, 0(x1)
    lh x6, 0(x1)
    lhu x7, 0(x1)

    sb x2, 140(x0)
    sh x2, 145(x0)
loop:
    j loop
