;
; Master code.asm
;
; Created: 11/9/2023 4:51:23 PM
; Author : HuyNguyen
;
;init the LCD
;LCD_D7..LCD_D4 connect to PA7..PA4
;LCD_RS connect to PA0
;LCD_RW connect to PA1
;LCD_EN connect to PA2
.equ LCDPORT = PORTA ; Set signal port reg to PORTA
.equ LCDPORTDIR = DDRA ; Set signal port dir reg to PORTA
.equ LCDPORTPIN = PINA ; Set clear signal port pin reg to PORTA
.equ LCD_RS = PINA0
.equ LCD_RW = PINA1
.equ LCD_EN = PINA2
.equ LCD_D7 = PINA7
.equ LCD_D6 = PINA6
.equ LCD_D5 = PINA5
.equ LCD_D4 = PINA4
;main
.org 0x0000 ; interrupt vector table
			rjmp reset_handler ; reset
.org 0x0004
			jmp INT1_ISR
;******************************* Program ID *********************************
.org 0x0040
reset_handler:
			call LCD_Init
			call USART_Init
			clr r19			; ISR counter to corrected output
			;SPI Master setup
			sbi ddrb,7		; Set SCLK pin to output
			sbi ddrb,5		; MOSI output
			sbi portb,6		; Pull up resistor for MISO
			sbi ddrb,4		; Set SS pin as output
			sbi ddrb,1		; Flag for slave
			sbi portb,4		; Pull SS pin to high
			ldi r16,(1<<SPE0)|(1<<MSTR0)|(1<<SPR10); Enable SPI set as master
			out SPCR0,r16
			;Interrupt setup
			ldi r16,(1<< ISC11)
			sts EICRA,r16	; Setup falling edge external int for INT1
			ldi r16,(1<<INT1)
			out EIMSK,r16
			sei				; Set up global interrrupt flag

start:		rjmp start

;-----------------------------------------------------------------------------
INT1_ISR:
			ldi r16,0x02		; Clear LCD screen
			call LCD_Send_Command
			ldi r16,0x00		; Dummy data to generate clk
			out SPDR0,r16
			cbi portb,4			; Clear SS pin
check:
			in r16, SPSR0		; Check SPI completion
			sbrs r16,7			; Check flag
			jmp check
			sbi portb,1			; Send flag to slave
			in r18,SPDR0		; Take out the data sent by the slave
			call ASCII_OUT
next:		cpi r19,0			; First output is wrong so skip it
			breq done_ISR
			call LCD_Send_Data	; Send to LCD
			call ASCII_OUT
			call USART_SendChar	; Send to UART
done_ISR:
			cbi portb,1			; Clear flag to slave
			inc r19
			reti
;-----------------------------------------------------------------------------
ASCII_OUT:
			cpi r18,10
			brlo number
			ldi r16,55
			add r16,r18			; ASCII correction for letter
			jmp exit

number:		ldi r16,'0'			; ASCII correction for number
			add r16,r18
exit:		ret
;-----------------------------------------------------------------------------
LCD_Init:
			; Set up data direction register for Port A
			ldi r16, 0b11110111 ; set PA7-PA4 as outputs, PA2-PA0 as output
			out LCDPORTDIR, r16
			; Wait for LCD to power up
			call delay_10ms
			call delay_10ms
			; Send initialization sequence
			ldi r16, 0x02 ; Function Set: 4-bit interface
			call LCD_Send_Command
			ldi r16, 0x28 ; Function Set: enable 5x7 mode for chars 
			call LCD_Send_Command
			ldi r16, 0x0C ; Display Control: Display OFF, Cursor ON
			call LCD_Send_Command
			ldi r16, 0x01 ; Clear Display
			call LCD_Send_Command
			ldi r16, 0x80 ; Clear Display
			call LCD_Send_Command
			ret

LCD_wait_busy:
			push r16
			ldi r16, 0b00000111 ; set PA7-PA4 as input, PA2-PA0 as output
			out LCDPORTDIR, r16
			ldi r16,0b11110010 ; set RS=0, RW=1 for read the busy flag
			out LCDPORT, r16
			nop
LCD_wait_busy_loop:
			sbi LCDPORT, LCD_EN
			nop
			nop
			in r16, LCDPORTPIN
			cbi LCDPORT, LCD_EN
			nop
			sbi LCDPORT, LCD_EN
			nop
			nop
			cbi LCDPORT, LCD_EN
			nop
			andi r16,0x80
			cpi r16,0x80
			breq LCD_wait_busy_loop
			ldi r16, 0b11110111 ; set PA7-PA4 as output, PA2-PA0 as output
			out LCDPORTDIR, r16
			ldi r16,0b00000000 ; set RS=0, RW=1 for read the busy flag
			out LCDPORT, r16
			pop r16
			ret

; Subroutine to send command to LCD
;Command code in r16
;LCD_D7..LCD_D4 connect to PA7..PA4
;LCD_RS connect to PA0
;LCD_RW connect to PA1
;LCD_EN connect to PA2
LCD_Send_Command:
			push r17
			call LCD_wait_busy ; check if LCD is busy 
			mov r17,r16 ;save the command
			; Set RS low to select command register
			; Set RW low to write to LCD
			andi r17,0xF0
			; Send command to LCD
			out LCDPORT, r17 
			nop
			nop
			; Pulse enable pin
			sbi LCDPORT, LCD_EN
			nop
			nop
			cbi LCDPORT, LCD_EN
			swap r16
			andi r16,0xF0
			; Send command to LCD
			out LCDPORT, r16 
			; Pulse enable pin
			sbi LCDPORT, LCD_EN
			nop
			nop
			cbi LCDPORT, LCD_EN
			pop r17
			ret

LCD_Send_Data:
			push r17
			call LCD_wait_busy ;check if LCD is busy
			mov r17,r16 ;save the command
			; Set RS high to select data register
			; Set RW low to write to LCD
			andi r17,0xF0
			ori r17,0x01
			; Send data to LCD
			out LCDPORT, r17 
			nop
			; Pulse enable pin
			sbi LCDPORT, LCD_EN
			nop
			cbi LCDPORT, LCD_EN
			; Delay for command execution
			;send the lower nibble
			nop
			swap r16
			andi r16,0xF0
			; Set RS high to select data register
			; Set RW low to write to LCD
			andi r16,0xF0
			ori r16,0x01
			; Send command to LCD
			out LCDPORT, r16
			nop
			; Pulse enable pin
			sbi LCDPORT, LCD_EN
			nop
			cbi LCDPORT, LCD_EN
			pop r17
			ret
; Function to move the cursor to a specific position on the LCD
; Assumes that the LCD is already initialized
; Input: Row number in R16 (0-based), Column number in R17 (0-based)
LCD_Move_Cursor:
			cpi r16,0 ;check if first row
			brne LCD_Move_Cursor_Second
			andi r17, 0x0F
			ori r17,0x80 
			mov r16,r17
			; Send command to LCD
			call LCD_Send_Command
			ret

LCD_Move_Cursor_Second:
			cpi r16,1 ;check if second row
			brne LCD_Move_Cursor_Exit ;else exit 
			andi r17, 0x0F
			ori r17,0xC0 
			mov r16,r17 
			; Send command to LCD
			call LCD_Send_Command
LCD_Move_Cursor_Exit:
			; Return from function
			ret

; Subroutine to send string to LCD
;address of the string on ZH-ZL
;string end with Null
.def LCDData = r16
LCD_Send_String:
			push ZH ; preserve pointer registers
			push ZL
			push LCDData
			; fix up the pointers for use with the 'lpm' instruction
			lsl ZL ; shift the pointer one bit left for the lpm instruction
			rol ZH ; write the string of characters
LCD_Send_String_01:
			lpm LCDData, Z+ ; get a character
			cpi LCDData, 0 ; check for end of string
			breq LCD_Send_String_02 ; done
			; arrive here if this is a valid character
			call LCD_Send_Data ; display the character
			rjmp LCD_Send_String_01 ; not done, send another character
			; arrive here when all characters in the message have been sent to the LCD module
LCD_Send_String_02:
			pop LCDData
			pop ZL ; restore pointer registers
			pop ZH
			ret
delay_1ms:	LDI R16,250	; number of inner loop
			LDI R17,11	; number of outer loop
COUNT_250:	DEC R16		; running inner loop
			BRNE COUNT_250
LOOP:		DEC R17		; outer loop
			BREQ STOP
			LDI R16,250	; reset inner loop counter
			RJMP COUNT_250
STOP:		RET

delay_10ms:	LDI R18,10	; COUNTER FOR LOOP
LOOP_10:	CALL delay_1ms
			DEC R18
			BRNE LOOP_10
			RET
;-----------------------------------------------------------------------------
;init UART 0
;CPU clock is 1Mhz
USART_Init:
			; Set baud rate to 9600 bps with 1 MHz clock
			ldi r16, 103
			sts UBRR0L, r16
			;set double speed
			ldi r16, (1 << U2X0)
			sts UCSR0A, r16
			; Set frame format: 8 data bits, no parity, 1 stop bit
			ldi r16, (1 << UCSZ01) | (1 << UCSZ00)
			sts UCSR0C, r16
			; Enable transmitter and receiver
			ldi r16, (1 << RXEN0) | (1 << TXEN0)
			sts UCSR0B, r16
			ret

;send out 1 byte in r16
USART_SendChar:
			push r17
			; Wait for the transmitter to be ready
			USART_SendChar_Wait:
			lds r17, UCSR0A
			sbrs r17, UDRE0 ;check USART Data Register Empty bit
			rjmp USART_SendChar_Wait
			sts UDR0, r16 ;send out
			pop r17
			ret