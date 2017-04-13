.. include:: ../../../README.rst

Scope of library
----------------
This library provides a unified interface to the Ethernet Microphone Array,
WiFi Microphone Array and Smart Mic Array base board. The library provides
support for configuring the clocks, interacting with the buttons and driving
the LEDs of those boards.

Intended use
------------
The board support interface can be accessed via the ``mic_array_board_support.h`` header::

  #include "mic_array_board_support.h"

You also have to add ``mic_array_board_support`` to the
``USED_MODULES`` field of your application Makefile.

API
---

Functions
.........

.. doxygenfunction:: mabs_button_and_led_server
.. doxygenfunction:: mabs_init_pll

Interfaces
..........
.. doxygeninterface:: mabs_led_button_if

Supporting types
................

.. doxygenenum:: mabs_button_state_t
.. doxygenenum:: mabs_board_t
.. doxygenstruct:: mabs_led_ports_t

Known Issues
------------

No known issues.

.. include:: ../../../CHANGELOG.rst
