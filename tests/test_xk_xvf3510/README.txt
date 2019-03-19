To run the tests into this folder the following steps must be followed:

  1. Flash in an RPi Hat board the .xe file in ./test_rpi_hat_clocks/bin/

  2. Add a pull-up resistor between pin 4 and pin 3 (I2C_SDA) in the DAC board

  3. Connect the following pins between the RPi Hat board J5 expander and the DAC board:
        - 5V power: pin 2
        - PI_MCLK:  pin 5
        - I2S_BCLK: pin 12
        - I2S_LRCK: pin 35
        - ground

  4. Connect a 3.5mm audio cable between LINE OUT of the DAC board and LINE IN of the XVF3510 board
  
  5. Power up both the RPi Hat board and the XVF3510 board (the DAC board is powered up via the RPi Hat board)
  
  6. Run all the tests in the folders test_xk_xvf3510_l71_* via XTAG:
        - "xrun --io test_xk_xvf3510_l71_audio.xe" returns 0 if successful
        - "xrun --io test_xk_xvf3510_l71_buttons.xe" requires some manual actions and returns 0 if successful
        - "xrun test_xk_xvf3510_l71_led.xe" requires some manual actions and it never returns
 

