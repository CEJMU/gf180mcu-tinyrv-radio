.section .text._start
.globl _start
_start:
    # csrw mstatus, x0 # Disable interrupts
    # la x5, isr_jt # Load base address
    # slli x5, x5, 2 # Make room for mode
    # ori x5, x5, 0b01 # Set mode to vectored
    # csrw mtvec, x5
    # li x5, 2048
    # csrw mie, x5

    # li x13, 0x100086
    # sw x0, 0(x13) # Set mtime     0
    # sw x0, 1(x13) # Set mtimeh    0
    # sw x0, 2(x13) # Set mtimecmp  0
    # sw x0, 3(x13) # Set mtimecmph 0

    # li x1, 0x1000
    # sw x1, 2(x13) # Set mtimecmp 0x1000

    # li x13, 8
    # csrw mstatus, x13 # Enable interrupts
    # li x13, 0x100002

    addi x5, x0, 180 # base address
    addi x6, x0, 196

    #t1
    addi x7, x0, 1
    #t2
    addi x8, x0, 1
    #next
    addi x9, x0, 1

    # next = t1 + t2;
    # t1 = t2;
    # t2 = next;

loop:
    add x9, x8, x7
    add x7, x0, x8
    add x8, x0, x9

    sw x8, 0(x5)

    addi x5, x5, 4
    bne x5, x6, loop

end:
    addi x1, x0, 1
    bne x1, x0, end

intr_timer_handle:
    li x12, 1338
    csrw mie, x0
    # li x14, 122
    # sw x14, 0(x13)
    mret

intr_ext_handle:
    # li x12, 1337
    li x14, 122
    sw x14, 0(x13)
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
    j intr_ext_handle # cause 11 (external interrupt)
    nop # cause 12
    nop # cause 13
    nop # cause 14
    nop # cause 15
