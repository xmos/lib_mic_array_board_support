Microphone array board support library
======================================

.. rheader::

   Microphone array board support library |version|

Microphone array board support library
--------------------------------------

Library for controlling the XMOS microphone array ref design 1v0.


Features
........

The microphone array board support library has the following features:

  * button and led interface

Typical Resource Usage
......................

.. resusage::

  * - configuration: Default
    - globals: in port p_buttons = MIC_BOARD_SUPPORT_BUTTON_PORTS; mabs_led_ports_t leds = MIC_BOARD_SUPPORT_LED_PORTS;
    - locals: interface mabs_led_button_if lb[1];
    - fn: mabs_button_and_led_server(lb, 1, leds, p_buttons);
    - pins: 13
    - ports: 3 (1-bit), 1 (4-bit), 2 (8-bit)

Software version and dependencies
.................................

.. libdeps::

Related application notes
.........................

None avaliable.

  
