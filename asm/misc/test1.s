loop:
    ADDI x1, x0, 5
    ADD x2, x0, x1
    MUL x3, x2, x1
    SW x3, 4(x0)
    LW x4, 4(x0)
    BNE x1, x0, loop
    MUL x5, x2, x1
    MUL x5, x2, x1
    MUL x5, x2, x1
    MUL x5, x2, x1
