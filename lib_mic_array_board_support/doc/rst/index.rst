.. include:: ../../../README.rst

Scope of library
----------------
This library provides an interface for interacting with the buttons and leds on the XMOS
microphone array reference design 1v0. 

Intended use
------------
The board support interface can be accessed via the ``mic_array_board_support.h`` header::

  #include "mic_array_board_support.h"

You also have to add ``mic_array_board_support`` to the
``USED_MODULES`` field of your application Makefile.





API
---

Supporting types
................

.. doxygenenum:: e_button_state
.. doxygenstruct:: p_leds
.. doxygeninterface:: led_button_if
.. doxygenfunction:: button_and_led_server

Known Issues
------------

No known issues.

.. include:: ../../../CHANGELOG.rst
