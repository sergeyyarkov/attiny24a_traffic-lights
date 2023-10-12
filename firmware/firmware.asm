; Project name: Traffic Lights
; Description: Simple program of traffic lights on AVR microcontroller.
; Source code: https://github.com/sergeyyarkov/attiny24a_traffic-lights 
; Device: ATtiny45v
; Assembler: AVR macro assembler 2.2.7
; Clock frequency: 128 kHz
; Fuses: lfuse: 0xd4, hfuse: 0xdf, efuse: 0xff, lock: 0xff
;
; Written by Sergey Yarkov 06.10.2023

.LIST
    
.INCLUDE "definitions.asm"

.MACRO stsi
    ldi		t1, @1
    sts		@0, t1
.ENDMACRO
    
.DSEG
.ORG	SRAM_START

STATE: 	.BYTE 1

.CSEG

.ORG 	0x00
    rjmp	RESET_vect

.ORG	0x03
    rjmp	TIMER1_COMPA

RESET_vect:
    ldi		t1, LOW(RAMEND)
    out		SPL, t1
     
INIT:
    ; Setup ports
    ldi		t1, 	(1<<ROAD_R_LED) | (1<<ROAD_Y_LED) | (1<<ROAD_G_LED) | (1<<WALK_R_LED) |	(1<<WALK_G_LED)
    out		DDRB, 	t1
    clr		t1
    out		LED_PORT, 	t1
  
    ; ====== Setup 8-bit Timer Counter 1 =======================================
    ; Freq(t) = 128kHz / 1024 = 125Hz
    ; Tick(t) = 1 / Freq(t) = 1 / 125Hz = uS (0.008 sec)
    ; Ticks per second = 1 sec / 0.008 sec = 125
    ; ==========================================================================
    clr 	t1						; clear timer counter register
    out		TCNT1, t1				
    ldi		t1, 125						; <== 1 second 
    out		OCR1A, t1
    ldi		t1, (1<<OCIE1A)					; enable output compare A interrupt
    out		TIMSK, t1
	
    ; Setup sleep mode in power-down
    in 		t1,  MCUCR
    ori		t1, (1<<SM1)
    out		MCUCR, t1
	
    ; Setup global variables
    clr		cycles
    stsi	STATE, 0
	
    sei

LOOP:	
    lds		t3, STATE	
_S0:								; State 0
    cpi		t3, 0
    brne	_S1
    sbi		LED_PORT, WALK_G_LED	
    sbi		LED_PORT, ROAD_R_LED	
    rcall	TIMER_ON
    cpi		timer_secs, DELAY_STATE_0
    breq	_S0_TIMER
    rjmp	END
_S0_TIMER:
    cbi		LED_PORT, ROAD_R_LED
    stsi	STATE, 1
    rcall TIMER_OFF
    clt
    rjmp	END
	
	
_S1:								; State 1
    cpi		t3, 1
    brne	_S2
    rcall	TIMER_ON
    cpi		timer_secs, DELAY_STATE_1
    breq	_S1_TIMER
    sbi		LED_PORT, ROAD_R_LED
    rcall	DELAY
    cbi		LED_PORT, ROAD_R_LED
    rcall	DELAY
    rjmp	END
_S1_TIMER:
    cbi		LED_PORT, ROAD_Y_LED
    mov 	t1, cycles
    cpi		t1, MAX_CYCLES
    brge	MCU_SLEEP
    stsi	STATE, 2
    rcall TIMER_OFF
    rjmp	END
	
	
_S2:								; State 2
    cpi		t3, 2
    brne	_S3
    sbi		LED_PORT, ROAD_Y_LED
    rcall	TIMER_ON
    cpi		timer_secs, DELAY_STATE_2
    breq	_S2_TIMER
    rjmp	END
_S2_TIMER:
    cbi		LED_PORT, ROAD_Y_LED
    brts	_CYCLE_DONE
    rjmp	_S2_NEXT
_CYCLE_DONE:
    cbi		LED_PORT, WALK_R_LED
    inc		cycles
    stsi	STATE, 0
    rjmp	END
_S2_NEXT:
    cbi		LED_PORT, WALK_G_LED	
    sbi		LED_PORT, WALK_R_LED	
    stsi	STATE, 3
    rcall 	TIMER_OFF
    rjmp	END
	
_S3:								; State 3
    cpi		t3, 3
    brne	_S4
    sbi		LED_PORT, ROAD_G_LED
    rcall	TIMER_ON
    cpi		timer_secs, DELAY_STATE_3
    breq	_S3_TIMER
    rjmp	END
_S3_TIMER:
    cbi		LED_PORT, ROAD_G_LED
    stsi	STATE, 4
    rcall TIMER_OFF
    rjmp	END
	
_S4:								; State 4
    cpi		t3, 4
    brne	END
    rcall	TIMER_ON
    cpi		timer_secs, 2
    breq	_S4_TIMER
    sbi		LED_PORT, ROAD_G_LED
    rcall	DELAY
    cbi		LED_PORT, ROAD_G_LED
    rcall	DELAY
    rjmp	END
_S4_TIMER:
    cbi		LED_PORT, ROAD_G_LED
    stsi	STATE, DELAY_STATE_4
    set
    rcall TIMER_OFF
END:
    rjmp	LOOP
	
MCU_SLEEP:
    in		t1, MCUCR
    ori		t1, (1<<SE)
    out		MCUCR, t1
    clr		t1
    out		LED_PORT, t1
    sleep
	
TIMER1_COMPA:							; Increment timer seconds register
    push	t1
    push	t2
    in		t1, SREG
    inc		timer_secs
    clr		t2
    out		TCNT1, t2
    out		SREG, t1
    pop		t2
    pop		t1
    reti

TIMER_OFF:
    in		t1, TCCR1
    andi	t1, ~(TIMER1_PRESCALE_MASK)
    out		TCCR1, t1
    clr		t1
    out		TCNT1, t1
    mov 	timer_secs, t1
    ret

TIMER_ON:
    in		t1, TCCR1
    ori		t1, TIMER1_PRESCALE_MASK
    out		TCCR1, t1
    ret
	
DELAY:
    push	t1
    push	t2			
    ldi		t2, 60	
_l1:
    ldi		t1, 150
_l0:
    dec		t1			
    brne	_l0		
    dec		t2			
    brne	_l1			
    pop		t2			
    pop		t1			
    ret				 		