.cpu _65c02
#import "Libraries/constants.asm"
#import "Libraries/petscii.asm"
#import "Macros/macro.asm"

BasicUpstart2(Main)

Main:
    addressRegisterByValue(
        DATA_PORT0,
        // The address we want to start at.
        // Then add the offset to place it in the same place as before.
        $1B000 + (15 * $100) + 22,
        // FIX: every SECOND byte.
        ADDRESS_STEP_2,
        ADDRESS_DIR_FORWARD
    )

    ldy #0

Looper:
    lda Message,y
    beq Exit        // If character is zero, then message has finished.
    sta VERADATA0   // Poke the character onto the screen.
    iny             // Increment pointer
    bra Looper      // Loop

Exit:
    jmp *

.encoding "screencode_mixed"

Message:
    .text "commander x16 says hello world"
    .byte $00
