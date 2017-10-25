// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include <xs1.h>
#include "mic_array_board_support.h"
#include <stdio.h>
#include <timer.h>


#define LED_MAX_COUNT (0xfffff)

/** Minimum period between polling the timer case, specified in microseconds
 *
 *  As a combinable task cannot currently support an ordered select + default
 *  case, it is necessary to back the timer case off to avoid the starving other
 *  combined tasks of MIPS.
 *
 *  This will impact the achievable resolution of the LED PWM.
 */
#define MIN_POLL_TIME_US (4 * XS1_TIMER_MHZ)

[[combinable]]
void mabs_button_and_led_server(server interface mabs_led_button_if lb[n_lb],
        static const unsigned n_lb,
#ifndef MIC_BOARD_LED_STCP
        mabs_led_ports_t &leds,
#else
        client interface ma_bga167_led_if leds,
#endif
        in port p_buttons){

    mabs_button_state_t latest_button_pressed = BUTTON_RELEASED;
    unsigned latest_button_id = BUTTON_EVENT_NONE;

    #if defined(PORT_LED_OEN)
    leds.p_leds_oen <: 1;
    leds.p_leds_oen <: 0;
    #endif

    unsigned led_brightness[MIC_BOARD_SUPPORT_LED_COUNT] = {0};
    timer t;
    unsigned time;
    unsigned start_of_time;
    t :> start_of_time;
    t :> time;

    unsigned button_val;
    p_buttons :> button_val;
    while(1){
        //[[ordered]]
        select {
        case lb[int i].set_led_brightness(unsigned led, unsigned brightness):{
            if(led < MIC_BOARD_SUPPORT_LED_COUNT)
                led_brightness[led] = brightness;
            break;
        }
        case lb[int i].set_led_ring_brightness(unsigned brightness): {
            for (int i=0; i < 12; i++) {
                led_brightness[i] = brightness;
            }
            break;
        }
        case lb[int i].get_button_event(unsigned &button, mabs_button_state_t &pressed):{
            button = latest_button_id;
            pressed = latest_button_pressed;
            break;
        }
        case p_buttons when pinsneq(button_val):> unsigned new_button_val:{
#define REPS 512
            unsigned button_count[4] = {0};
            unsigned diff = button_val^new_button_val;
            for(unsigned i=0;i<4;i++)
                button_count[i] += ((diff>>i)&1);
            for(unsigned i=0;i<REPS;i++){
                p_buttons :> new_button_val;
                diff = button_val^new_button_val;
                for(unsigned i=0;i<4;i++)
                    button_count[i] += ((diff>>i)&1);
            }
            for(unsigned i=0;i<4;i++){
                button_val ^= ((1<<i)*(button_count[i]>(REPS/2)));
                if( button_count[i]>(REPS/2)){
                    latest_button_id = i;
                    latest_button_pressed = (button_val>>i)&1;
                    for (int j=0; j < n_lb; j++) {
                        lb[j].button_event();
                    }
                }
            }
            break;
        }

        case t when timerafter(time) :> unsigned now :{
            time = now + MIN_POLL_TIME_US;
            unsigned elapsed = (now-start_of_time)&LED_MAX_COUNT;
            elapsed>>=(20-8);
            unsigned d=0;
#if defined(MIC_BOARD_LED_STCP)

            for(unsigned i=0; i<13; i++)
                d=(d>>1)+(0x1000*(led_brightness[i]<=elapsed));
            leds.set_leds(d);
#else
#if defined(PORT_LED0_TO_7)
            for(unsigned i=0;i<8;i++)
                d=(d>>1)+(0x80*(led_brightness[i]<=elapsed));
            leds.p_led0to7 <: d;
#endif
#if defined(PORT_LED8)
            leds.p_led8 <: (led_brightness[8]<=elapsed);
#endif
#if defined(PORT_LED9)
            leds.p_led9 <: (led_brightness[9]<=elapsed);
#endif
#if defined(PORT_LED8_TO_11)
            d=0;
            for(unsigned i=8;i<12;i++)
                d=(d>>1)+(0x80*(led_brightness[i]<=elapsed));
            leds.p_led8to11 <: d;
#endif
#if defined(PORT_LED10_TO_12)
            d=0;
            for(unsigned i=10;i<13;i++)
                d=(d>>1)+(0x4*(led_brightness[i]<=elapsed));
            leds.p_led10to12 <: d;
#endif
#if defined(PORT_LED_12)
            leds.p_led12 <: (led_brightness[12]<=elapsed);
#endif
#endif
            break;
        }
        /*
        default:{
            unsigned now;
            t:> now;
            unsigned elapsed = (now-start_of_time)&LED_MAX_COUNT;
            elapsed>>=(20-8);
            unsigned d=0;
            for(unsigned i=0;i<8;i++)
                d=(d>>1)+(0x80*(led_brightness[i]<=elapsed));
            leds.p_led0to7 <: d;
            leds.p_led8 <: (led_brightness[8]<=elapsed);
            leds.p_led9 <: (led_brightness[9]<=elapsed);
            d=0;
            for(unsigned i=10;i<13;i++)
                d=(d>>1)+(0x4*(led_brightness[i]<=elapsed));
            leds.p_led10to12 <: d;
            break;
        }
        */
        }
    }
}
