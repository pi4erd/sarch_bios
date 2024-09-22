#!/bin/sh

echo "Compiling bios.s..."
sarch_asm -b bios.s -o bios.sao

# link bios.sao as main file
# everything else as libraries
echo "Linking..."
sarch_asm -k --link -c link.json bios.sao -o bios.bin
echo "Finished!"
