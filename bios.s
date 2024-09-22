.section "text"

.define BIOS_END        0x100000
.define QUERY_BASE      BIOS_END
.define RAM_START_QUERY (QUERY_BASE + 0x18)
.define RAM_END_QUERY   (RAM_START_QUERY + 4)

.define RAM_START       0x200000

.define STACK_SIZE      0x100

.define DISK0_ADDR      (BIOS_END + 0x010000)
.define STDIO_ADDR      (BIOS_END + 0x020000)

.define BOOT_SIGNATURE 0xDEADBEEF

; Should always start at 0x00000000
start:
    dsin
    loadid (RAM_START + STACK_SIZE) r2

    movrd sp r2
    movrd bp sp

    loadid it_start tptr ; load interrupt table
    esin

init_boot:
    ; TODO: Add support for multiple boot drives
    loadid 0 r0
    loadid 4 r1 ; load 4 blocks (aka 1 KiB)
    loadid (RAM_START + 0x10000) r2 ; load boot in 0x210000
    int 0x02

    loadmd (RAM_START + 0x210000) r0      ; load first 4 bytes
    icmpud BOOT_SIGNATURE r0 ; compare boot signature
    jpc (RAM_START + 4) ZR   ; jump if has boot signature
@error:
    loadid msg_not_bootable r1
    int 0x04
    halt

; takes r0 block offset to read
; takes r1 block count to read (max 256)
; takes r2 buffer address to write to
; returns r0 status code (0 = success)
i_read_disk:
    push r2

    icmpud 256 r1
    jrc @error GTR

    push r0
    push r1
    radd r0 r1
    loadmd 0x110004 r1 ; get disk size
    rcmpud r0 r1
    jrc @error ZR
    jrc @error GTR ; if LastReadBlock >= DiskSize -> error
    pop r1
    pop r0

    ; Set on-disk block pointer
    stmd DISK0_ADDR r0
    loadid 0 r3
    stmd 0x110004 r3

@loop:
    ; if i == 0 -> exit
    icmpud 0 r1
    jrc @success ZR

    loadid 0 r3

@load_block:
    ; if byteptr >= 256 -> next block
    icmpud 256 r3
    jrc @next_iter ZR

    stmb 0x110008 r30l ; set byte ptr for buffer
    loadmd 0x110008 r4 ; read 4 bytes from buffer into r4
    stptrd r4 r2 ; write 4 bytes into buffer
    iadd 4 r2 ; increase buffer ptr by 4
    iadd 4 r3 ; increase byte ptr
    jpr @load_block

@next_iter:
    iadd 1 r0
    isub 1 r1
    jpr @loop

@error:
    loadid 1 r0
    jmp @end
@success:
    loadid 0 r0
@end:
    pop r2
    ret

; returns ram start in r0
i_get_ram_start:
    loadmd RAM_START_QUERY r0
    ret

; returns ram end in r0
i_get_ram_end:
    loadmd RAM_END_QUERY r0
    ret

; prints char in r00l
i_print_char:
    stmb STDIO_ADDR r00l
    ret

; prints string at r1
; uses r00l as buffer
i_print_str:
    ldptrb r1 r00l ; load [r1] => r00l
    iadd 1 r1 ; increment r1
    icmpub 0 r00l ; if r00l == 0 return
    jrc @end ZR
    stmb STDIO_ADDR r00l
    jpr i_print_str
@end:
    ret

.section "rodata"
msg_not_bootable:
    .db "Not a bootable drive!" 0x0A 0x00

.section "interrupts"
it_start:
.dd i_get_ram_start ; 0
.dd i_get_ram_end   ; 1
.dd i_read_disk     ; 2
.dd i_print_char    ; 3
.dd i_print_str     ; 4
.dd 0x0000
.dd 0x0000
.dd 0x0000
