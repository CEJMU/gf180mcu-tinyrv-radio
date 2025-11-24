ENTRY(_start)
OUTPUT_FORMAT(elf32-littleriscv)

SECTIONS{
    .text : {
        *(.text._start);
        *(.text*);
    }
}
