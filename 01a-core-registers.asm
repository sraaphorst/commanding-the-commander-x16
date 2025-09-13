.cpu _65c02
#importonce

// To see results, enable the debugger and enter: v 0138a5
// You should see a 55 in the first memory location of the first eight columns shown.

BasicUpstart2(Main)

Main:
    // Set the data port we want to use.
    // Also sets the auto incrementor to zero.
    lda #0
    sta $9f25

    // Set VERA memory low address.
    lda #$A5
    sta $9F20

    // Set VERA memory middle address.
    lda #$38
    sta $9F21

    // Set VERA memory high (data bank).
    lda #$01

    // This loads 5, then shift left 5 places as the address increment
    // uses the high nibble of the byte, so easier to let the assembler
    // work it out. Increments by 16.
    ora #$05 << 4

    // Set VERA memory high (data bank).
    // See Appendix A ADDR_H ($9F22) for details on auto-increment.
    sta $9F22

    ldx #$08

Looper:
    // Load the value we want to store in VERA memory.
    // Location $138A5 and every 8 bytes after that.
    lda #$55

    // DATA0
    sta $9F23
    dex
    bne Looper
    jmp *

