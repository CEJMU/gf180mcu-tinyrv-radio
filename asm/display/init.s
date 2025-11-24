.section .text
.global init_display

# Does not save any registers
init_display:
    # t0: Address of I2C display
    # t1: Storing the byte

    li t0, 0x01000003
    li t1, 60
    sw t1, 1(t0) # Store 60 in device addr
    li t1, 3
    sw t1, 2(t0) # 3 in byte mask (two LSBs)

    li t1, 0x000000AE
    sw t1, 0(t0)

    li t1, 0x000000A4
    sw t1, 0(t0)

    li t1, 0x000000D5
    sw t1, 0(t0)

    li t1, 0x00000050
    sw t1, 0(t0)

    li t1, 0x000000A8
    sw t1, 0(t0)

    li t1, 0x0000003F
    sw t1, 0(t0)

    li t1, 0x000000D3
    sw t1, 0(t0)

    li t1, 0x00000000
    sw t1, 0(t0)

    li t1, 0x00000040
    sw t1, 0(t0)

    li t1, 0x000000AD
    sw t1, 0(t0)

    li t1, 0x0000008B
    sw t1, 0(t0)

    li t1, 0x000000DA
    sw t1, 0(t0)

    li t1, 0x00000012
    sw t1, 0(t0)

    li t1, 0x00000081
    sw t1, 0(t0)

    li t1, 0x000000CF
    sw t1, 0(t0)

    li t1, 0x000000D9
    sw t1, 0(t0)

    li t1, 0x00000022
    sw t1, 0(t0)

    li t1, 0x000000DB
    sw t1, 0(t0)

    li t1, 0x00000035
    sw t1, 0(t0)

    li t1, 0x000000A4
    sw t1, 0(t0)

    li t1, 0x000000A6
    sw t1, 0(t0)

    li t1, 0x000000DA
    sw t1, 0(t0)

    li t1, 0x00000012
    sw t1, 0(t0)

    li t1, 0x000000A1
    sw t1, 0(t0)

    li t1, 0x000000C8
    sw t1, 0(t0)

    li t1, 0x00000000
    sw t1, 0(t0)

    li t1, 0x00000010
    sw t1, 0(t0)

    li t1, 0x000000AF
    sw t1, 0(t0)

    jalr x0, ra, 0 # Return from function
