.section .text._start
.globl _start
_start:
    li x2, 0x100003 # base address
    li x6, 0xDEADBEEF # value
    li x5, 60 # i2c address
    sw x5, 1(x2) # set address

    # Test mask 0001
    li x5, 1
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 0010
    li x5, 2
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 0011
    li x5, 3
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 0100
    li x5, 4
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 0101
    li x5, 5
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 0110
    li x5, 6
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 0111
    li x5, 7
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 1000
    li x5, 8
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 1001
    li x5, 9
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 1010
    li x5, 10
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 1011
    li x5, 11
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 1100
    li x5, 12
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 1101 (fehlt)
    li x5, 13
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 1110
    li x5, 14
    sw x5, 2(x2)
    sw x6, 0(x2)

    # Test mask 1111
    li x5, 15
    sw x5, 2(x2)
    sw x6, 0(x2)

end:
    j end
