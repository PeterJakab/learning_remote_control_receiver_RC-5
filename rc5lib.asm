;**********************************************************************
;                                                                     *
;    Filename:	    rc5lib.asm                                        *
;    Date:                                                            *
;    File Version:                                                    *
;                                                                     *
;    Author:        el@jap.hu                                         *
;                   http://jap.hu/electronic/                         *
;**********************************************************************
;NOTES
;
; RC5 IR decoding routine
;
; T ~= 890 usec at 4Mhz (half bit)
;
;**********************************************************************
;HISTORY
;
;000-20010314
;initial version
;
;001-20010314-2
;library
;
;RC5 format:
; header = 2xbit1
; toggle = 1xbit
; device = 5xbit
; cmd    = 6xbit
;**********************************************************************

	list      p=16F628

	GLOBAL rc5_receive
	GLOBAL rc5_tog_dev, rc5_command

#include <p16F628.inc>
#define RXBIT PORTA, 4

;normal
;define SKL btfsc
;define SKH btfss

;reverse
#define SKL btfss
#define SKH btfsc

; these values are at: 0.5T, 1.5T, 2.5T, 9xinstr.time counts
min_t		EQU	.49
min_2t		EQU	.148
max_2t		EQU	.247

LOOPDELAY macro
	; these are added to the 9 cycle instructions
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop ; 18 cycles till here

	nop
	nop
	nop
	nop ; 22

endm


;***** VARIABLES
#define IF_SHORT flags, 0
#define FIRST_HALF flags, 1
#define HEADER flags, 2
#define VALID flags, 7

if_short_val	EQU	1 ; bit value of IF_SHORT flag
first_half_val	EQU	2 ; bit value of FIRST_HALF flag

.rc5da UDATA

bitcnt		res	1
tmrval		res	1 ; timer value
bt		res	1 ; receive byte buffer
flags		res	1 ; decode logic status
btcnt		res	1 ; byte counter

rc5_tog_dev	res	1 ; toggle and device id
rc5_command	res	1 ; received rc5 command

		CODE

rc5_receive	; receive a full manchester-encoded packet

s3		; set flags: first_half=1, if_short=0
		bsf FIRST_HALF
s4		bcf IF_SHORT

s5		; init before the received packet

		; set FSR to buffer start
		movlw rc5_tog_dev
		movwf FSR
		; set byte counter
		movlw 2
		movwf btcnt
		; set header receive mode
		bsf HEADER
		clrf bitcnt ; counting bit1-s in this mode

s2		; wait for a pulse
		SKH RXBIT
		goto s2

s6		; wait for end of (short) pulse up to min_2t
		clrf tmrval
s6_w		SKH RXBIT
		goto s7 ; goto s7 at end of pulse

		incf tmrval, F
		nop
		;LOOPDELAY

		movlw min_2t
		subwf tmrval, W
		btfss STATUS, C
		goto s6_w

		; timeout, exit
		retlw 1 ; illegal startbit

s7		; start timer
		clrf tmrval

s8		; if (if_short & rxbit) goto s9
		; if (!if_short & !rxbit) goto s9
		; goto s10

		btfsc IF_SHORT
		; if_short = 1
		goto s8_ss1

s8_ss0		; if_short = 0
		SKL RXBIT
		goto s10 ; rxbit = 1, goto s10

s9_ss0		; if (timer > max_2t) exit - else goto s8
		movlw max_2t
		subwf tmrval, W
		btfsc STATUS, C
		retlw 2 ; signal too long

		incf tmrval, F
		;LOOPDELAY

		goto s8_ss0

s8_ss1		; if_short = 1
		SKH RXBIT
		goto s10 ; rxbit = 0, goto s10

s9_ss1		; if (timer > max_2t) exit - else goto s8
		movlw max_2t
		subwf tmrval, W
		btfsc STATUS, C
		retlw 2 ; signal too long

		incf tmrval, F
		;LOOPDELAY

		goto s8_ss1

s10		; invert if_short
		movlw if_short_val
		xorwf flags, F

s11		; if (timer < min_t) exit
		movlw min_t
		subwf tmrval, W
		btfss STATUS, C
		retlw 3 ; signal too short

s12		; if (timer < min_2t) goto s14
		movlw min_2t
		subwf tmrval, W
		btfss STATUS, C
		goto s14

s13		; if (first_half = 0) goto s16 - else exit
		btfss FIRST_HALF
		goto s16
		retlw 4 ; no mid-frame transition/out of sync

s14		; invert first_half
		movlw first_half_val
		xorwf flags, F

s15		; if (first_half = 1) goto 7
		btfsc FIRST_HALF
		goto s7

s16		; if_short is a decoded bit. Handle here
		btfss HEADER
		goto s16_not_header

		; header receiving mode
		btfss IF_SHORT
		retlw 5 ; invalid header

		; header bit is 1
		incf bitcnt, F
		;;btfss bitcnt, 1 ; inc up to 2
		;;goto s7 ; loop back

		; 1 header bit1s received
		; (first 1 is implicitly decoded)
		bcf HEADER

next_byte	movlw 0x06
		movwf bitcnt
		goto s7 ; loop back

s16_not_header	; receiving bytes
s16_s2		; bit is data
		rrf flags, W
		rlf bt, F

		decf bitcnt, F
		bz s16_s4 ; if (bitcnt = 0), received OK
		goto s7

s16_s4		; OK, store received byte
		movlw 0x3f
		andwf bt, W
		movwf INDF
		incf FSR, F

		decfsz btcnt, F
		goto next_byte

		retlw 0 ; OK, buffer received

		end

