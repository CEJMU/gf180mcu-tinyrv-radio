# This program shows an example on how to use the GPIO pins
# There are 8 outputs and 8 inputs. Refer to the cpu.pcf file for the exact mapping
# They can be accessed by reading or writing to specific memory addresses (memory mapped IO)

.section .text._start
.globl _start
_start:
    # ================ Output Example ================
    li s0, 0x01000000   # Address of GPIO Output (8 GPIO Pins as one byte)

    li t0, 0xFF       # Load all 1's
    sw t0, 0(s0)      # Write all 1's to the GPIO outputs (8 least significant bits are used)

    li t0, 0xAB       # Load 10101011 into register
    sw t0, 0(s0)      # Update GPIO output values


    # ================ Input/Output Example ================
# li s1, 0x01000001       # Address of GPIO Inputs (8 GPIO Pins as one byte)
# loop:
    # lw t1, 0(s1)      # Load 8 input bits into register (8 least significant bits)
    # andi t1, t1, 1    # Bitwise AND with 0000_0001 (set all bits to zero except LSB)
                      # Unconnected pins are not really 0 but floating somewhere

    # bne t1, x0, one   # Branch if the LSB is set to 1

  # zero:
      # li t0, 0x0
      # sw t0, 0(s0)    # Turn off LED by setting all outputs to 0
      # j loop          # Unconditionally loop

  # one:
      # li t0, 0xFF
      # sw t0, 0(s0)    # Turn on LED by setting all outputs to 1
      # j loop          # Loop around
