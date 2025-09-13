.cpu _65c02
#importonce

// To see results, enable the debugger and enter: v 0138a5
// You should see a 55 in the first memory location shown.

BasicUpstart2(Main)

Main:
    // First we must set the Data Port we want to use.
    lda #0
    sta $9F25
    // This will also set the auto incrementor to Zero.

    lda #$A5    // Set VERA Memory Low Address
    sta $9F20

    lda #$38    // Set VERA Memory Middle Address
    sta $9F21

    lda #$01    // Set VERA Memory High (Data Bank)
    sta $9F22

    lda #$55    // load the value we want to store in VERA Memory
                // location $138A5
    sta $9F23   // DATA0

    jmp *
