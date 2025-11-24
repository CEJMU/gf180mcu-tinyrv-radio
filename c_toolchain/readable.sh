#!/usr/bin/env sh

hexdump -v -e '1/1 " %02X" "\n"' demo.bin | sed 's/ //g' > demo.txt
