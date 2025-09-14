.cpu _65c02
#import "Libraries/constants.asm"
#import "Libraries/petscii.asm"
#import "Macros/macro.asm"

BasicUpstart2(Main)

Main:
    // Change screen configuration to be similar to C64, 40 cols x 24 rows.
    lda #$03
    clc
    jsr SCREEN_MODE

    // In this example, we use the foreground and background colour.
    // 0  -  7  Character index
    // 8  - 11 Background colour
    // 12 - 15 Foreground colour
    addressRegisterByValue(
        DATA_PORT0,
        // The address we want to start at.
        // Then add the offset to place it in the same place as before.
        // Note that the first number is row count, second is 2 * column count.
        $1B000 + (12 * $100) + 14,
        ADDRESS_STEP_1,
        ADDRESS_DIR_FORWARD
    )

    ldy #0

Looper:
    lda Message,y
    beq Exit        // If character is zero, then message has finished.
    sta VERADATA0   // Poke the character onto the screen.
    lda #BLACK << 4 | YELLOW
    sta VERADATA0
    iny             // Increment pointer
    bra Looper      // Loop

Exit:
    jmp *

.encoding "screencode_mixed"

Message:
    // 25 characters
    .text "commander x16 says hi c64"
    .byte $00
