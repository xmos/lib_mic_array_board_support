// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef MIC_ARRAY_BOARD_SUPPORT_H_
#define MIC_ARRAY_BOARD_SUPPORT_H_

#define MAX_LED_BRIGHTNESS 256

#define DEFAULT_INIT {XS1_PORT_8C, XS1_PORT_1K, XS1_PORT_1L, XS1_PORT_8D, XS1_PORT_1P}

/** This type is used to describe an event on a button.
 */
typedef enum {
    BUTTON_PRESSED  = 0,    ///< Button is depressed.
    BUTTON_RELEASED = 1     ///< Button is released.
} e_button_state;

/** Structure to describe the LED ports*/
typedef struct {
    out port p_led0to7;     /**<LED 0 to 7. */
    out port p_led8;        /**<LED 8. */
    out port p_led9;        /**<LED 9. */
    out port p_led10to12;   /**<LED 10 to 12. */
    out port p_leds_oen;    /**<LED Output enable (active low). */
} p_leds;


/** This interface is used to set the brightness of the LEDs and create
 * events on button presses.
 */
interface led_button_if {

    /** Sets the bightness of an LED.
    *
    *  \param led         The address of the led to set the brightness of.
    *  \param brightness  The buffer containing data to write.
    */
  void set_led_brightness(unsigned led, unsigned brightness);


  /** Button event notification.
  *
  *  This notification will fire when any button is pressed or released.
   */
  [[notification]] slave void button_event(void);

  /** Gets the latest button event.
  *
  *  \param button    The address of the button that caused the event.
  *  \param pressed   The state the button that caused the event.
  */
  [[clears_notification]] void get_button_event(unsigned &button, e_button_state &pressed);
};

void button_and_led_server(server interface led_button_if lb, p_leds &leds, in port p_buttons);


#endif /* MIC_ARRAY_BOARD_SUPPORT_H_ */
