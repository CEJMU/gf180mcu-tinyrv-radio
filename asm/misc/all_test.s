.section .text._start
.globl _start
_start:
    addi x1, x0, 1 # x1 = 1
    add x2, x1, x1 # x2 = 2
    sub x3, x2, x1 # x3 = 2-1 = 1
    mul x3, x2, x2 # x3 = 2*2 = 4

    # and, or, ...

    lui x5, 100 # 409600
    auipc x6, 100 # 20 + 409600
    sw x6, 20(x0)
