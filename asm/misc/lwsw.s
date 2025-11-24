.section .text._start
.globl _start
_start:
  addi x1, x0, 10
  sw x1, 40(x0)
  sw x1, 160(x0)
  sw x1, 180(x0)
loop:
  bne x1, x0, loop
