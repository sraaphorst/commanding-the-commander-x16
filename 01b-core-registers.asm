.cpu _65c02
#importonce

#import "Libraries/constants.asm"
#import "Macros/macro.asm"

BasicUpstart2(Main)

Main:
    addressRegisterByValue(
        DATA_PORT0,
        $138A5,
        ADDRESS_STEP_16,
        ADDRESS_DIR_FORWARD
    )

    // The number of rows to affect.
    ldx #$08

Looper:
    lda #$55

    sta $9F23
    dex
    bne Looper
    jmp *
