.section .text._start
.globl _start
_start:

    la x1, 0x1000010 # freq_status
    sw x0, 0(x1) # Set everthing to 0

    li x2, 0b11
    slli x2, x2, 30
    li x3, 0b000000001011101001011110001101
    or x2, x2, x3
    sw x2, 1(x1) # Set osr & f_c

    li x2, 4
    sw x2, 2(x1) # Set lo_div

    li x2, 1
    sw x2, 0(x1) # Deactivate reset
    li x2, 3
    sw x2, 0(x1) # Deactivate reset and start sending

loop:
    j loop # Let cordic + dsmod do their magic
