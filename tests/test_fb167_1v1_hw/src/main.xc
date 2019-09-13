// Test of LEDs and buttons.
#include <xs1.h>
#include <platform.h>
#include <limits.h>
#include <stdlib.h>
#include "debug_print.h"

// Buttons
in port p_buttons               = on tile[0]: XS1_PORT_4F;
// LED controller ports
out port p_led_stcp				= on tile[3] : XS1_PORT_1A;
out port p_led_shcp 			= on tile[3] : XS1_PORT_1B;
out port p_led_data 			= on tile[3] : XS1_PORT_1E;
out port p_led_oe_n 			= on tile[3] : XS1_PORT_1F; 

enum buttons
{
  BUTTON_A=1<<0,
  BUTTON_B=1<<1,
  BUTTON_C=1<<2,
  BUTTON_D=1<<3
};

#define BUTTON_PRESSED(but_mask, old_val, new_val) (((old_val) & (but_mask)) == (but_mask) && ((new_val) & (but_mask)) == 0)
#define BUTTON_DEBOUNCE_DELAY (20000000)
#define NUM_BUTTONS 4

void led_driver(out port stcp, out port shcp, out port data, int led_value)
{
  stcp <: 0;
  shcp <: 0;
  data <: 0;
  
  led_value = ~led_value; // LEDs are ON when output is low.

  for (int i = 0; i < 16; i++)
  {
    data <: (led_value & 0x8000) >> 15;
    shcp <: 0;
    delay_microseconds(10);
    shcp <: 1;
    delay_microseconds(10);
    led_value = led_value << 1;
  }
  
  data <: 0;
  shcp <: 0;
  delay_microseconds(10);
  stcp <: 1;
  delay_microseconds(10);
  stcp <: 0;
}

void led_flash()
{
  int pattern;
  p_led_oe_n <: 0;
  while(1)
  {
    pattern = 0x0001;
    for(int i = 0; i < 13; i++)
    {
      led_driver(p_led_stcp, p_led_shcp, p_led_data, pattern);
      pattern = pattern << 1;
      delay_microseconds(200000);
    }
  }
  return;
}

void buttons_test(void) {
  int button_val;
  int buttons_active = 1;
  unsigned buttons_timeout;
  timer button_tmr;

  p_buttons :> button_val;

  unsigned buttons_pressed[NUM_BUTTONS] = {0,0,0,0};

  while (1) {
    int all_pressed = 1;
    for (int i = 0; i < NUM_BUTTONS; i++) {
      if (buttons_pressed[i] == 4) {
        debug_printf("Button pressed 4 times, press again to exit.\n");
        // Prevent message being printed again
        buttons_pressed[i] += 1;
      } else if (buttons_pressed[i] > 5) {
        debug_printf("FAIL\n");
        exit(1);
      } else if (buttons_pressed[i] == 0) {
        all_pressed = 0;
      }
    }
    if (all_pressed) {
      debug_printf("PASS\n");
      exit(0);
    }

    select
    {
      case buttons_active => p_buttons when pinsneq(button_val) :> unsigned new_button_val:

        if BUTTON_PRESSED(BUTTON_A, button_val, new_button_val) {
          debug_printf("Button A\n");
          buttons_pressed[0] += 1;
          buttons_active = 0;
        }
        if BUTTON_PRESSED(BUTTON_B, button_val, new_button_val) {
          debug_printf("Button B\n");
          buttons_pressed[1] += 1;
          buttons_active = 0;
        }
        if BUTTON_PRESSED(BUTTON_C, button_val, new_button_val) {
          debug_printf("Button C\n");
          buttons_pressed[2] += 1;
          buttons_active = 0;
        }
        if BUTTON_PRESSED(BUTTON_D, button_val, new_button_val) {
          debug_printf("Button D\n");
          buttons_pressed[3] += 1;
          buttons_active = 0;
        }
        if (!buttons_active)
        {
          button_tmr :> buttons_timeout;
          buttons_timeout += BUTTON_DEBOUNCE_DELAY;
        }
        button_val = new_button_val;
        break;
      case !buttons_active => button_tmr when timerafter(buttons_timeout) :> void:
        buttons_active = 1;
        p_buttons :> button_val;
        break;
    }
  }
}
	

int main(void) {
	
	par {
		on tile[0] : buttons_test();
		on tile[3] : led_flash();
	}
	return 0;
}