# Main file
# This program gives you a complete example of doing something useful
# with the 132x64 OLED display. It is very unoptimized but should be fairly easy
# to understand. It consists of a 132x64 array of pixels and a function that can
# draw this array on the display. First, the display is set to all-black and then a
# diagonal line is stored in the array and drawn to the display.
#
# Some register in RISC-V are callee-saved, meaning that any function that is called
# is responsible for making sure their contents are not affected by the function call.
# This is achieved by storing their contents in memory after entering the function and
# restoring the contents from memory before returning from the function.
# When using recursion, the function arguments must also be saved on the stack so their
# contents are not overwritten. This is left out here, because it is not needed
#
# The example is structured in three files:
# - init.s: Contains the initialisation sequence of the display. You may just copy this sequence.
# - draw.s: Defines functions for accessing the pixels by (x,y) and drawing the array
# - main.s: Creates important variables, calls the initialisation and draw function

.section .text._start
.globl _start
_start:
    # Address of the i2c display. The base address of i2c devices is 0x100004
    # and the display has the internal address 0x3C. 0x100004 + 0x3C = 0x100040
    # When sending data to the display, you can mask the bytes that are sent. A sw will always
    # store 4 bytes, but the most significant byte is used to mask the 3 others. Example:
    # 0x06_123456 will write 1234 (0x06 = 0b110)
    # 0x05_123456 will write 1256 (0x05 = 0b101)
    # ...
    li t0, 0x100040

    # Base address of pixel array P (address is arbitrary)
    # We want to store 132x64. P[0] - P[131] is y = 0, P[132] - P[263] is y = 1, ...
    # The address of any point (x,y) can then be computed by P[132*y + x]
    li s0, 30000

    li sp, 99000 # stack base pointer (grows down, address is arbitrary)

    # Set the entire array to 0 (the memory has undefined contents)
    li s1, 0 # x
    li s10, 132 # x max
    li s2, 0 # y
    li s11, 64 # y max

    y_loop:
        li s1, 0 # Start of new outer iteration, set x to 0

        x_loop:
            li a0, 0 # Load pixel value 0 into function register
            addi a1, s1, 0 # Load x-coordinate into function register
            addi a2, s2, 0 # Load y-coordinate into function register
            jal ra, set_pixel # set P(x,y) to 0
            addi s1, s1, 1 # x++
            bne s1, s10, x_loop

        addi s2, s2, 1 # y++
        bne s2, s11, y_loop

    jal ra, init_display # Initialise the display configuration itself
    j loop

loop:
    jal ra, draw_display # Draw the memory once (set all pixels to black)

    li s1, 0
    li s2, 0
    li s3, 64

    # Draw the diagonal line into memory
    inner:
        li a0, 1
        addi a1, s1, 0
        addi a2, s2, 0
        jal ra, set_pixel
        addi s1, s1, 1
        addi s2, s2, 1
        bne s2, s3, inner

    jal ra, draw_display # Draw the line on the display
end:
    j end
