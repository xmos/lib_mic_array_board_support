Microphone array board support library change log
=================================================

3.0.0
-----

  * Update the supported hardware revision of xCORE Microphone Array to 1V3
  * Update the supported hardware revision of xCORE WiFi Microphone Array to 1V1
  * Remove 'p_leds_oen' port from mabs_led_ports_t

2.1.0
-----

  * Allow the mabs_button_and_led_server task to be combined. As a combinable
    task cannot currently support an ordered select + default case, the timer
    case is now run with a constant minimum period to ensure that any other
    tasks combined with it are not starved.

2.0.0
-----

  * Added support for the xCORE WiFi Microphone Array board 1V0
  * Updated API to avoid conflicts in global namespace

  * Changes to dependencies:

    - lib_i2c: Added dependency 3.1.3

    - lib_logging: Added dependency 2.0.1

    - lib_xassert: Added dependency 2.0.1

1.0.0
-----

  * Update to button/LED server to support multiple clients
  * Outer LED ring interface call added

0.2.2
-----

  * Update to source code license and copyright

0.2.1
-----

  * Added MCLK presence and rate detection to 1v0 hardware test

0.2.0
-----

  * Updated documentation

0.1.0
-----

  * Initial Release

