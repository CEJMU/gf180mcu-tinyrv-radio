.section .text._start
.globl _start
_start:
    csrw mstatus, x0 # Disable interrupts
    la x5, isr_jt # Load base address
    ori x5, x5, 0b01 # Set mode to vectored
    csrw mtvec, x5
    li x5, 2048 # Enable external interrupts
    csrw mie, x5

    li x13, 0x01000002 # Load address of UART
    li x1, 0x01000000 # Load address of GPIO out
    li x2, FF
    li x14, 8
    csrw mstatus, x14 # Enable interrupts

loop:
    sw x0, 0(x1)
    j loop

intr_ext_handle:
    li x13, 97 # write a
    sw x13, 0(x14)
    sw x2, 0(x1)
    mret

isr_jt:
    nop # cause 0
    nop # cause 1
    nop # cause 2
    nop # cause 3 (software interrupt)
    nop # cause 4
    nop # cause 5
    nop # cause 6
    nop # cause 7 (timer interrupt)
    nop # cause 8
    nop # cause 9
    nop # cause 10
    j intr_ext_handle # cause 11 (external interrupt)
    nop # cause 12
    nop # cause 13
    nop # cause 14
    nop # cause 15
