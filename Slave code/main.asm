;
; Slave code.asm
;
; Created: 11/9/2023 4:22:58 PM
; Author : HuyNguyen
;
;main
;I/O set up
sbi ddrb,0; IRQ pin PB0S
sbi portb,0; IRQ pin always ON (OFF when have an interrupt)
sbi portb,1; done SPI procedure flag
;SPI setup
sbi portb,4; pull up resistor for SS 
sbi portb,5; pull up resistor for MOSI 
sbi portb,7; pull up resistor for SCLK
sbi ddrb,6; set MISO pin to output
ldi r16,(1<<SPE0)
out  SPCR0,r16; set up the SPI control register

		;dummy cycle
		call delay_300ms
		ldi r23,1
		jmp skip
;Scan keypad loop
scan_key:
		call keypad_scan
skip:
		cpi r23,0xFF	; check if any key is press 
		brne key_found	; if yes jump to send data to master
		jmp scan_key	; if no check again
key_found:	
		out SPDR0,r23	; send data to SPI data register
		cbi portb,0		; IQR pull low
		sbi portb,0		; pull the IRQ pin up
check:
		in r16, pinb	; check SPI completion
		sbrs r16,1		; check flag
		jmp check	
		call delay_300ms
		jmp scan_key
;-----------------------------------------------------------------------------------------------------
; ATmega324PA keypad scan function
; Scans a 4x4 keypad connected to PORTA
; C3-C0 connect to PA3-PA0
; R3-R0 connect to PA7-PA4
; Returns the key value (0-15) or 0xFF if no key is pressed
keypad_scan:
		 ldi r20, 0b00001111 ; set upper 4 bits of PORTD as input with pull-up, lower 4 bits as output
		 out DDRA, r20
		 ldi r20, 0b11111111 ; enable pull up resistor 
		 out PORTA, r20
		 ldi r22, 0b11110111 ; initial col mask
		 ldi r23, 0 ; initial pressed row value
		 ldi r24,3 ;scanning col index
keypad_scan_loop:
		 out PORTA, r22 ; scan current col
		 nop ;need to have 1us delay to stablize
		 sbic PINA, 4	; check row 0
		 rjmp keypad_scan_check_col2
		 rjmp keypad_scan_found ; row 0 is pressed
keypad_scan_check_col2:
		 sbic PINA, 5	; check row 1
		 rjmp keypad_scan_check_col3
		 ldi r23, 1		; row1 is pressed
		 rjmp keypad_scan_found
keypad_scan_check_col3:
		 sbic PINA, 6	; check row 2
		 rjmp keypad_scan_check_col4
		 ldi r23, 2		; row 2 is pressed
		 rjmp keypad_scan_found
keypad_scan_check_col4:
		 sbic PINA, 7	; check row 3
		 rjmp keypad_scan_next_row
		 ldi r23, 3		; row 3 is pressed
		 rjmp keypad_scan_found
keypad_scan_next_row:
		 ; check if all rows have been scanned
		 cpi r24,0
		 breq keypad_scan_not_found
		 ; shift row mask to scan next row
		 ror r22
		 dec r24 ;increase row index
		 rjmp keypad_scan_loop
keypad_scan_found:
		 ; combine row and column to get key value (0-15)
		 ; key code = row*4 + col
		 lsl r23		; shift row value 4 bits to the left
		 lsl r23
		 add r23, r24	; add row value to column value
		 ret
keypad_scan_not_found:
		 ldi r23, 0xFF	; no key pressed
		 ret
;----------------------------------------------------------------------------
delay_1ms:
		LDI R21,8	;1MC
L1: 
		LDI R20,250 ;1MC
L2: 
		DEC R20		;1MC
		NOP			;1MC
		BRNE L2		;2/1MC
		DEC R21		;1MC
		BRNE L1		;2/1MC
		RET			;4MC

delay_300ms:
		LDI R19, 3	; OUTER LOOP COUNTER
		LDI R18,100	; COUNTER FOR INNER LOOP
LOOP_1s:
		CALL delay_1ms
		DEC R18
		BRNE LOOP_1s
		DEC R19
		BREQ STOP_1s
		LDI R18,100
		RJMP LOOP_1S
STOP_1s:	
		RET