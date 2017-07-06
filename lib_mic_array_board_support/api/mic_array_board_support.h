// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#ifndef MIC_ARRAY_BOARD_SUPPORT_H_
#define MIC_ARRAY_BOARD_SUPPORT_H_

#include <platform.h>
#include "i2c.h"

#define MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS 256
#define MIC_BOARD_SUPPORT_LED_COUNT 13

#define MIC_BOARD_SUPPORT_BUTTON_PORTS  PORT_BUT_A_TO_D

#if defined(PORT_LED_OEN)
#define MIC_BOARD_SUPPORT_LED_PORTS     {PORT_LED0_TO_7, PORT_LED8, PORT_LED9, PORT_LED10_TO_12, PORT_LED_OEN}
#else
#define MIC_BOARD_SUPPORT_LED_PORTS     {PORT_LED0_TO_7, PORT_LED8, PORT_LED9, PORT_LED10_TO_12}
#endif

/** This type is used to describe an event on a button.
 */
typedef enum {
    BUTTON_PRESSED  = 0,    ///< Button is depressed.
    BUTTON_RELEASED = 1     ///< Button is released.
} mabs_button_state_t;

/** Special value for the initial event before any buttons pressed.
 */
#define BUTTON_EVENT_NONE (-1)

/** Structure to describe the LED ports*/
typedef struct {
    out port p_led0to7;     /**<LED 0 to 7. */
    out port p_led8;        /**<LED 8. */
    out port p_led9;        /**<LED 9. */
    out port p_led10to12;   /**<LED 10 to 12. */
#if defined(PORT_LED_OEN)
    out port p_leds_oen;    /**<LED Output enable (active low). */
#endif
} mabs_led_ports_t;

/**
 * Supported board types
 */
typedef enum {
   ETH_MIC_ARRAY,
   WIFI_MIC_ARRAY,
   SMART_MIC_BASE
} mabs_board_t;



/** Configure the PLL for the specified board.
 *
 * \param i2c   The i2c bus used to configure the audio codec.
 * \param board Specifies the type of board being used.
 */
void mabs_init_pll(client i2c_master_if i2c, mabs_board_t board);

/** This interface is used to set the brightness of the LEDs and create
 * events on button presses.
 */
interface mabs_led_button_if {

  /** Sets the bightness of an LED.
  *
  *  \param led         The address of the led to set the brightness of.
  *  \param brightness  The buffer containing data to write.
  */
  void set_led_brightness(unsigned led, unsigned brightness);

  /** Sets the bightness of the outer ring of LEDs.
  *
  *  \param brightness  The brightness value of outer LEDs
  */
  void set_led_ring_brightness(unsigned brightness);

  /** Button event notification.
  *
  *  This notification will fire when any button is pressed or released.
   */
  [[notification]] slave void button_event(void);

  /** Gets the latest button event.
  *
  *  \param button    The address of the button that caused the event.
  *  \param pressed   The state the button that caused the event.
  *
  *  Returns BUTTON_EVENT_NONE the first time round.
  */
  [[clears_notification]] void get_button_event(unsigned &button,
          mabs_button_state_t &pressed);
};

/** A task to handle the LEDs and buttons of a microphone array board.
 *
 * This task can be combined with other tasks.
 * 
 * \param lb          An array of client interfaces.
 * \param n_lb        The number of client tasks connected to this server.
 * \param leds        The structure containing the ports used to drive the LEDs.
 * \param p_buttons   The port to which the buttons are mapped.
 */
[[combinable]]
void mabs_button_and_led_server(server interface mabs_led_button_if lb[n_lb], static const unsigned n_lb,
        mabs_led_ports_t &leds, in port p_buttons);


#endif /* MIC_ARRAY_BOARD_SUPPORT_H_ */
