To run the tests into this folder the following repository must be cloned:
  - lib_i2c
  - lib_i2s
  - lib_dsp
  - lib_logging

The following steps must be followed:

  1. Flash in an RPi Hat board the .xe file in ./test_rpi_hat_clocks/bin/

  2. Ensure the following have been added to the 3510 test board (JGB0051):
      a) A 10k pull-up resistor between SDA and 3V3 
      b) A link from MLCK to pin 7 on J5
      c) A zero ohm resistor on R32
      d) 4.7k Pull ups to SPI_MOSI, SPI_MISO, and SPI_CLK

  3. Connect the RPi Hat board J5 to the DAC board with a 2x40 pin cable

  4. Connect a 3.5mm audio cable between LINE OUT of the DAC board and LINE IN of the XVF3510 board
  
  5. Power up both the RPi Hat board and the XVF3510 board (the DAC board is powered up via the RPi Hat board)
  
  6. Run all the tests in the folders test_xk_xvf3510_l71_* via XTAG:
        - "xrun --io test_xk_xvf3510_l71_audio.xe" returns 0 if successful
        - "xrun --io test_xk_xvf3510_l71_buttons.xe" requires some manual actions and returns 0 if successful
        - "xrun test_xk_xvf3510_l71_led.xe" requires some manual actions and it never returns
 

