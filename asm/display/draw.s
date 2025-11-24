.section .text
.global set_pixel
.global get_pixel
.global draw_display

# Macro definition to store all callee-saved register on the stack
# Note that a macro is not like a function. The assembler will copy-paste
# its contents. No jumps are involved. Its for convenience

.macro saveContext
    addi sp, sp, -48 # Make room on the stack for 12 register x 4 byte = 48 bytes
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    sw s4, 16(sp)
    sw s5, 20(sp)
    sw s6, 24(sp)
    sw s7, 28(sp)
    sw s8, 32(sp)
    sw s9, 36(sp)
    sw s10, 40(sp)
    sw s11, 44(sp)
.endm

# Macro for restoring them again
.macro restoreContext
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    lw s4, 16(sp)
    lw s5, 20(sp)
    lw s6, 24(sp)
    lw s7, 28(sp)
    lw s8, 32(sp)
    lw s9, 36(sp)
    lw s10, 40(sp)
    lw s11, 44(sp)
    addi sp, sp, 48
.endm

# Set pixel value of P[132*y + x]
set_pixel:
    # s0: base address of array
    # a0: pixel value (0 or 1)
    # a1: x
    # a2: y
    saveContext

    li s4, 132
    mul s5, a2, s4 # 132*y
    add s5, s5, a1 # 132*y + x
    li s4, 4
    mul s5, s5, s4 # * 4 to get right address (because 4 byte memory accesses)
    add s3, s0, s5 # base address + offset

    sw a0, 0(s3) # store it in the array

    restoreContext
    jalr x0, ra, 0

get_pixel:
    # s0: base address of array
    # a0: pixel value
    # a1: x
    # a2: y
    saveContext

    li s4, 132
    mul s5, a2, s4 # 132*y
    add s5, s5, a1 # 132*y + x
    li s4, 4
    mul s5, s5, s4 # * 4 to get right address
    add s3, s0, s5 # base address + offset

    lw a0, 0(s3) # load it in the array

    restoreContext
    jalr x0, ra, 0

# =============================================================
# The display has two ways it will interpret its data:
# - command: If the first byte is 0x00, then the following byte is interpreted as a command.
#            This could be to jump the cursor somewhere else, turn of the display, adjust the charge pump, ...
# - data: If the first byte is 0xC0, then the following byte is data. This byte is then display on the screen
#
# The screen is divided into 132 columns (== x-coordinate as usual) and 8 pages, with 8 pixels each (== 64 y-coordinates)
# The page has to be set by a command (shown below), the column address will be incremented automatically after
# each write (but can be set manually if desired) and the byte written to the display will set the 8 pixels of
# the current page and current column
# The datasheet shows this on page 16: https://www.displayfuture.com/Display/datasheet/controller/SH1106.pdf
          
draw_display:
    saveContext
    # t0: Address of I2C display
    # t1: Storing the byte
    li t0, 0x01000003
    li t1, 60
    sw t1, 1(t0) # Store 60 in device addr
    li t1, 3
    sw t1, 2(t0) # 3 in byte mask (two LSBs)

    li t2, 0 # Page
    li t3, 8 # Max. page

    page_loop:
        bge t2, t3, return # exit the loop if page >= 8

        li t1, 0x000000B0 # Load command byte (0x00) and room for data (0xB0)
        or t1, t1, t2 # Bitwise ORing to get B0 to B7
        sw t1, 0(t0) # Send 0x00Bx to the display (set the page cursor to x)

        li t4, 0 # column address
        li t5, 132 # Max

        column_loop:
            li t6, 0 # t6 holds the byte of 8 pixels for the display

            li s3, 8 # i = 8. Looping from 7 to 0
            row_loop:
                addi s3, s3, -1 # i--
                addi a1, t4, 0 # x-coordinate = column. Load into function call register

                # Compute correct y-coordinate
                li a2, 8
                mul a2, a2, t2 # 8*page
                add a2, a2, s3 # y = 8*page + i

                # Store ra on the stack and get P(x,y)
                addi sp, sp, -4
                sw ra, 0(sp)
                jal ra, get_pixel
                lw ra, 0(sp)
                addi sp, sp, 4

                slli t6, t6, 1
                or t6, t6, a0 # add pixel to the byte
                bne s3, x0, row_loop # loop back if i != 0

            # Transmit the byte in t6
            li t1, 0x0000C000 # Load data byte (0xC0) and room for content byte (0x00)
            or t1, t1, t6 # Add the data to the last byte
            sw t1, 0(t0) # Send draw command

            addi t4, t4, 1 # Increment column
            blt t4, t5, column_loop # loop, if column < 132

        addi t2, t2, 1 # Increment page
        j page_loop

return:
    restoreContext
    jalr x0, ra, 0 # Return from function
