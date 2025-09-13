.cpu _65c02
#import "Libraries/constants.asm"
#import "Libraries/petscii.asm"
#import "Macros/macro.asm"

BasicUpstart2(Main)

Main:
    // Initialize pointer.
    ldy #0

Looper:
    lda Message,y   // load character from message
    beq Exit        // if the character is zero, message has finished
    jsr CHROUT      // print the character to the screen
    iny             // increment pointer
    bra Looper      // loop

Exit:
    jmp *           // stop execution

.encoding "petscii_mixed"
Message:
    // HOME
    .byte $13
    // CUR DOWN
    .byte $11, $11, $11, $11, $11, $11, $11, $11, $11
    .byte $11, $11, $11, $11, $11, $11
    // CUR RIGHT
    .byte $1D, $1D, $1D, $1D, $1D, $1D, $1D, $1D, $1D, $1D, $1D
    .text "commander x16 says hello world"
    .byte $00
