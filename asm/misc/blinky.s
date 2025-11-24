.section .text._start
.globl _start
_start:
    csrw mstatus, x0 # Disable interrupts
    la x5, isr_jt # Load base address
    slli x5, x5, 2 # Make room for mode
    ori x5, x5, 0b01 # Set mode to vectored
    csrw mtvec, x5

    li x13, 0x100086
    sw x0, 0(x13) # Set mtime     0
    sw x0, 1(x13) # Set mtimeh    0
    sw x0, 2(x13) # Set mtimecmp  0
    sw x0, 3(x13) # Set mtimecmph 0

    li x1, 12000000
    # li x1, 0x1000
    sw x1, 2(x13) # Set mtimecmp 0x1000

    li x13, 128
    csrw mie, x13 # Only enable timer interrupts

    li x13, 8
    csrw mstatus, x13 # Enable interrupts in general

    li x13, 0x100000 # GPIO Out
    li x14, 0x100086 # mtime
    li x12, 0 # LED status
    li x11, 255
    # sw x11, 0(x13) # Turn LED on
loop:
    j loop

intr_timer_handle:
    bne x12, x0, led_on
    sw x11, 0(x13) # Turn LED on
    li x12, 1
    j reset_timer

led_on:
    sw x0, 0(x13) # Turn LED off now
    li x12, 0

reset_timer:
    sw x0, 0(x14)
    mret

isr_jt:
    nop # cause 0
    nop # cause 1
    nop # cause 2
    nop # cause 3 (software interrupt)
    nop # cause 4
    nop # cause 5
    nop # cause 6
    j intr_timer_handle # cause 7 (timer interrupt)
    nop # cause 8
    nop # cause 9
    nop # cause 10
    nop # cause 11 (external interrupt)
    nop # cause 12
    nop # cause 13
    nop # cause 14
    nop # cause 15
