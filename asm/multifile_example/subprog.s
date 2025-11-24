.section .text
.global sub
loop:
    bne x1, x0, loop

sub:
    addi x1, x1, 1
    jalr x0, x2, 0
