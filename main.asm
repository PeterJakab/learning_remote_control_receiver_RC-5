;**********************************************************************
;                                                                     *
;    Filename:	    main.asm                                          *
;    Date:                                                            *
;    File Version:                                                    *
;                                                                     *
;    Author:        el@jap.hu                                         *
;                   http://jap.hu/electronic/                         *
;**********************************************************************
; HISTORY
;
; 000 - 20010314 initial version
; 001 - 20120701 lookup table (type, channel)
; 002 - 20120714 lookup table moved into data eeprom
; 003 - 20120714 toggle, on, off modes
; 004 - 20120715 momentary mode added
; 005 - 20120715 cleanup
; 006 - 20120715 learn / decode
; 007 - 20120715 learn clear_one, clear_all
; 010 - 20120715 cleanup, define default rc buttons
;**********************************************************************
;
;    Notes:
;**********************************************************************

	list      p=16F627A
	__CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _XT_OSC & _LVP_OFF & _MCLRE_OFF

#include <p16F627a.inc>
#include "rc5lib.inc"

; these are not actually used anywhere...
#define TYPE_TOGGLE 0x00
#define TYPE_OFF 0x01
#define TYPE_ON 0x02
#define TYPE_MOMENTARY 0x03

VALID_LED	EQU 3
LEARN		EQU 5
EXPIRE_TIMER	EQU 0x30
NUM_CHANNELS	EQU .11

;***** VARIABLES
freemem		UDATA
c_type		res 1
c_channel	res 1
act_tog_dev	res 1
act_command	res 1

cur_state	res 2
cur_seq		res 1
expire_cnt	res 1
cur_ch		res 2
clear_ch	res 2

savew1		res 1
savestatus	res 1
savepclath	res 1
savefsr		res 1

lrn_channel	res 1
lrn_type	res 1

vectors		CODE 0

  		goto    main              ; go to beginning of program
		nop
		nop
		nop
		goto itr

eeprom_data	CODE 0x2110
toggle_ch	de 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff ; ch0-3
		de 0x00, 0x05, 0x00, 0x06, 0x00, 0x07, 0x00, 0x08 ; ch4-7
		de 0x00, 0x09, 0x00, 0xff, 0x00, 0xff; ch8-10

off_ch		de 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff ; ch0-3
		de 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff ; ch4-7
		de 0x00, 0xff, 0x00, 0xff, 0x00, 0x11; ch8-10

on_ch		de 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff ; ch0-3
		de 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff ; ch4-7
		de 0x00, 0xff, 0x00, 0xff, 0x00, 0x10; ch8-10

momentary_ch	de 0x00, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00, 0x03 ; ch0-3
		de 0x00, 0x04, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff ; ch4-7
		de 0x00, 0xff, 0x00, 0xff, 0x00, 0xff ; ch8-10
end_of_data	de 0xff

		CODE
channel_lookup_b
		addwf PCL, F
		dt 0x1, 0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x80 ; B0-B7

channel_lookup_a
		addwf PCL, F
		dt 0x01, 0x02, 0x04, 0x40, 0x80, 0x00, 0x00, 0x00 ; A0, A1, A2, A6, A7

type2address	addwf PCL, F
		dt LOW toggle_ch, LOW off_ch, LOW on_ch, LOW momentary_ch

search_codes	;
		clrf c_type
		movlw toggle_ch ; c_type = 0
		call search_1
		btfsc STATUS, Z
		return
		incf c_type, F
		movlw off_ch ; c_type = 1
		call search_1
		btfsc STATUS, Z
		return
		incf c_type, F
		movlw on_ch ; c_type = 2
		call search_1
		btfsc STATUS, Z
		return
		incf c_type, F
		movlw momentary_ch ; c_type = 3
		call search_1
		btfsc STATUS, Z
		return

		; no code found
		movlw 0xff
		movwf c_type
		movwf c_channel
		return

search_1	clrf c_channel
		BANKSEL EEADR
		movwf EEADR

search_2	
		BANKSEL EECON1
		bsf EECON1, RD
		movf EEDATA, W
		BANKSEL PORTA
		movwf act_tog_dev

		BANKSEL EEADR
		incf EEADR, F

		bsf EECON1, RD
		movf EEDATA, W
		BANKSEL PORTA
		movwf act_command
		movf act_command, W
		xorwf rc5_command, W
		btfss STATUS, Z
		goto search_next
		movlw 0x1f
		andwf rc5_tog_dev, W
		xorwf act_tog_dev, W
		btfsc STATUS, Z
		return ; Z=1 - found
search_next	
		BANKSEL EEADR
		incf EEADR, F
		BANKSEL PORTA
		incf c_channel, F
		movlw NUM_CHANNELS
		xorwf c_channel, W
		bnz search_2
		bcf STATUS, Z ; Z=0 - not found
		return

itr
		movwf	savew1
		movf	STATUS,w
		clrf	STATUS
		movwf	savestatus
		movf	PCLATH,w
		movwf	savepclath
		clrf	PCLATH
	
		movf	FSR,w
		movwf	savefsr
	
		btfsc	INTCON, T0IF
		call	t0_int_handler
	
		movf	savefsr,w
		movwf	FSR
	
		movf	savepclath,w
		movwf	PCLATH
	
		movf	savestatus,w
		movwf	STATUS
	
		swapf	savew1,f
		swapf	savew1,w
	
		retfie
	

main		;F628 HARDWARE INIT
		movlw 0
		movwf PORTA
		movwf PORTB
		movlw 7
		movwf CMCON ; disable comparators

		btfss PORTA, LEARN
		goto learn

		BANKSEL TRISA
		movlw 0x10
		movwf TRISA
		movlw 0
		movwf TRISB

		; setup TMR0 interrupt
		clrwdt ; changing default presc. assignment
		movlw 0x03 ; prescaler 1:16 assigned to TMR0
		movwf OPTION_REG ; T0CS selects internal CLK
		bsf INTCON, T0IE ; enable TMR0 int

		BANKSEL TMR0
		clrf TMR0
		clrf expire_cnt
		bsf INTCON, GIE

warm		clrf cur_state
		clrf cur_state+1
		clrf cur_seq
		movlw 0xff
		movwf clear_ch
		movwf clear_ch+1

loop		call rc5_receive
		andlw 0xff
		bnz loop
		; code received into rc5_tog_dev and rc5_command
		call search_codes
		bnz loop ; code not found

		; code found in lookup table: c_type and c_channel
rx_ok		movlw EXPIRE_TIMER ; indicate packet reception
		movwf expire_cnt

		movf rc5_tog_dev, W
		xorwf cur_seq, W
		andlw 0x20 ; toggle bit
		bz loop ; if (seq==cur_seq) skip (only expire timer is updated)

		movlw 0x20
		andwf rc5_tog_dev, W
		movwf cur_seq

		; check channel
		movlw NUM_CHANNELS
		subwf c_channel, W
		bc loop ; illegal channel data

		; lookup current channel
		movlw 0x07
		andwf c_channel, W
		btfss c_channel, 3
		goto channel_on_portb
channel_on_porta
		call channel_lookup_a
		movwf cur_ch
		clrf cur_ch+1
		goto channel_done

channel_on_portb
		call channel_lookup_b
		clrf cur_ch
		movwf cur_ch+1

channel_done	bcf INTCON, GIE

		btfsc c_type, 1
		goto state_type23
state_type01	btfsc c_type, 0
		goto state_type1

state_type0	; toggle
		; clear momentary
		movf cur_ch, W
		iorwf clear_ch, F
		movf cur_ch+1, W
		iorwf clear_ch+1, F

		movf cur_ch, W
		xorwf cur_state, F
		movf cur_ch+1, W
		xorwf cur_state+1, F
		goto state_done

state_type1	; off
		movlw 0xff
		xorwf cur_ch, W
		andwf cur_state, F
		movlw 0xff
		xorwf cur_ch+1, W
		andwf cur_state+1, F
		goto state_done

state_type23	btfss c_type, 0
		goto state_type2
state_type3	; set momentary
		movlw 0xff
		xorwf cur_ch, W
		andwf clear_ch, F
		movlw 0xff
		xorwf cur_ch+1, W
		andwf clear_ch+1, F
		goto state_on

state_type2	; on
		; clear momentary
		movf cur_ch, W
		iorwf clear_ch, F
		movf cur_ch+1, W
		iorwf clear_ch+1, F
state_on
		movf cur_ch, W
		iorwf cur_state, F
		movf cur_ch+1, W
		iorwf cur_state+1, F
		goto state_done

state_done	movlw (1<<VALID_LED)
		call state_out
		bsf INTCON, GIE
		goto loop


t0_int_handler	bcf INTCON, T0IF
		movf expire_cnt, F
		bnz valid_on

		; clear momentary outputs
		movf clear_ch, W
		andwf cur_state, F
		movf clear_ch+1, W
		andwf cur_state+1, F
		movlw 0

state_out	iorwf cur_state, W
		movwf PORTA
		movf cur_state+1, W
		movwf PORTB
		return

valid_on	decf expire_cnt, F
		return

learn
		BANKSEL TRISA
		movlw 0x10
		movwf TRISA
		movlw 0xff
		movwf TRISB

		; setup TMR0 interrupt
		clrwdt ; changing default presc. assignment
		movlw 0x03 ; prescaler 1:16 assigned to TMR0
		movwf OPTION_REG ; T0CS selects internal CLK
		BANKSEL PORTA
		clrf cur_seq

		; check for clear_all
		rrf PORTB, W
		andlw 0x07
		bz lrn_clear_all

loop2		call rc5_receive
		andlw 0xff
		bnz loop2

		movf rc5_tog_dev, W
		xorwf cur_seq, W
		andlw 0x20 ; toggle bit
		bz loop2 ; if (seq==cur_seq) skip (only expire timer is updated)

		movlw 0x20
		andwf rc5_tog_dev, W
		movwf cur_seq

		; code received into rc5_tog_dev and rc5_command
		; b1-b3: channel mode
		rrf PORTB, W
		andlw 0x07
		movwf lrn_type
		; b4-b7: channel number
		swapf PORTB, W
		andlw 0x0f
		xorlw 0x0f ; invert!
		movwf lrn_channel

		movlw 0x02 ; B1, B3 pushed: clear code
		xorwf lrn_type, W
		bz lrn_clear_one

		; check channel
		movlw NUM_CHANNELS
		subwf lrn_channel, W
		bc loop2 ; illegal channel data

		bcf STATUS, C
		rlf lrn_channel, F ; lrn_channel*=2
		call button2address
		bnz loop2 ; illegal button combination / no button pressed
		addwf lrn_channel, F ; compute eedata address
		; lrn_channel contains the eeprom data address

		; check if this code is already used
		call search_codes
		bz loop2 ; this code is already used for something, don't store

		movf lrn_channel, W
		BANKSEL EEADR
		movwf EEADR

		; write to data eeprom
		bsf EECON1, WREN
		BANKSEL PORTA

		movlw (1<<VALID_LED)
		movwf PORTA

		movlw 0x1f
		andwf rc5_tog_dev, W
		BANKSEL EEDATA
		movwf EEDATA
		movlw 0x55
		movwf EECON2
		movlw 0xaa
		movwf EECON2
		bsf EECON1, WR
eewr1		btfsc EECON1, WR
		goto eewr1

		incf EEADR, F
		BANKSEL PORTA
		movf rc5_command, W
		BANKSEL EEDATA
		movwf EEDATA
		movlw 0x55
		movwf EECON2
		movlw 0xaa
		movwf EECON2
		bsf EECON1, WR
eewr2		btfsc EECON1, WR
		goto eewr2

		bcf EECON1, WREN
		BANKSEL PORTA
		clrf PORTA
		; write done

		goto loop2

button2address	movlw 0x03 ; B3 pushed: type OFF
		xorwf lrn_type, W
		btfsc STATUS, Z
		retlw off_ch

		movlw 0x05; B2 pushed: type ON
		xorwf lrn_type, W
		btfsc STATUS, Z
		retlw on_ch

		movlw 0x01; B2, B3 pushed: toggle
		xorwf lrn_type, W
		btfsc STATUS, Z
		retlw toggle_ch

		movlw 0x06; B1 pushed: momentary
		xorwf lrn_type, W
		btfsc STATUS, Z
		retlw momentary_ch

		retlw 0xff

lrn_clear_one	call search_codes
		bnz loop2 ; not found

		BANKSEL EEADR
		movf EEADR, W
		call erase_address
		BANKSEL EEADR
		decf EEADR, W
		call erase_address
		BANKSEL PORTA
		goto lrn_clear_one

lrn_clear_all	movlw toggle_ch
		movwf lrn_channel
lrn_clear_2	movf lrn_channel, W
		call erase_address
		incf lrn_channel, F
		movlw end_of_data
		xorwf lrn_channel, W
		bnz lrn_clear_2
		goto loop2

erase_address	
		BANKSEL EEADR
		movwf EEADR

		; write to data eeprom
		bsf EECON1, WREN
		BANKSEL PORTA

		movlw (1<<VALID_LED)
		movwf PORTA

		movlw 0xff
		BANKSEL EEDATA
		movwf EEDATA
		movlw 0x55
		movwf EECON2
		movlw 0xaa
		movwf EECON2
		bsf EECON1, WR
eewr3		btfsc EECON1, WR
		goto eewr3

		bcf EECON1, WREN
		BANKSEL PORTA
		clrf PORTA
		; write done
		return

		end
