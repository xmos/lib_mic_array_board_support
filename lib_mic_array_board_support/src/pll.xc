// Copyright (c) 2016-2021, XMOS Ltd, All rights reserved
// This software is available under the terms provided in LICENSE.txt.
#include <xs1.h>
#include "mic_array_board_support.h"

#include "i2c.h"

void mabs_init_pll(client i2c_master_if i2c, mabs_board_t board){
    switch(board){
    case ETH_MIC_ARRAY:
        #define CS2100_DEVICE_CONFIG_1      0x03
        #define CS2100_GLOBAL_CONFIG        0x05
        #define CS2100_FUNC_CONFIG_1        0x16
        #define CS2100_FUNC_CONFIG_2        0x17

        i2c.write_reg(0x9c>>1, 0x02,  0x01);
        i2c.write_reg(0x9c>>1, CS2100_DEVICE_CONFIG_1,  0x00);
        i2c.write_reg(0x9c>>1, CS2100_GLOBAL_CONFIG,  0x00);
        i2c.write_reg(0x9c>>1, CS2100_FUNC_CONFIG_2,  0x10);
        i2c.write_reg(0x9c>>1, 0x02,  0x00);
        return;

    case SMART_MIC_BASE:
    case WIFI_MIC_ARRAY:
        // SI5351A Register Addresses
        #define SI5351A_OE_CTRL      (0x03) // Register 3  - Output Enable Control
        #define SI5351A_FANOUT_EN    (0xBB) // Register 187 - Fanout Enable Control

        #define SI5351A_MS0_R0_DIV   (0x2C) /* Register 44 - Multisynth0 Parameters:
                                             *  - R0_DIV[2:0]
                                             *  - MS0_DIVBY4[1:0]
                                             *  - MS0_P1[17:16]
                                             */
        #define SI5351A_MS2_R2_DIV   (0x3C) /* Register 60 - Multisynth2 Parameters:
                                             *  - R2_DIV[2:0]
                                             *  - MS2_DIVBY4[1:0]
                                             *  - MS2_P1[17:16]
                                             */

        #define SI5351A_CLK0_CTRL    (0x10) // Register 16 - CLK0 Control
        #define SI5351A_MS0_P1_UPPER (0x2D) /* Register 45 - Multisynth0 Parameters:
                                             *  - MS0_P1[15:8]
                                             */
        #define SI5351A_MS0_P2_LOWER (0x31) /* Register 49 - Multisynth0 Parameters:
                                             *  - MS0_P2[7:0]
                                             */

        #define SI5351A_CLK2_CTRL    (0x12) // Register 18 - CLK2 Control
        #define SI5351A_MS2_P1_UPPER (0x3D) /* Register 61 - Multisynth2 Parameters:
                                             *  - MS2_P1[15:8]
                                             */
        #define SI5351A_MS2_P2_LOWER (0x41) /* Register 65 - Multisynth2 Parameters:
                                             *  - MS2_P2[7:0]
                                             */
        i2c_regop_res_t res;
        // Configure SI5351A clock generator
          int clock_gen_i2c_address = 0x62;
        // Disable the CLK0 output (to xCORE MCLK in).
        res = i2c.write_reg(clock_gen_i2c_address, SI5351A_OE_CTRL, 0xFD);

        // Enable Fanout of MS0 to other outputs.
        res = i2c.write_reg(clock_gen_i2c_address, SI5351A_FANOUT_EN, 0xD0);

        /* Change R0 divider to divide by 2 instead of divide by 1.
         * This stays at this value.
         */
        res = i2c.write_reg(clock_gen_i2c_address, SI5351A_MS0_R0_DIV, 0x10);
        res = i2c.write_reg(clock_gen_i2c_address, SI5351A_MS2_R2_DIV, 0x30);

        /* MCLK = 24.576MHz (12,24,48,96,192kHz)
         * Sets powered up, integer mode, src PLLA, not inverted,
         * Sel MS0 as src for CLK0 o/p, 4mA drive strength
         */
        res = i2c.write_reg(clock_gen_i2c_address, SI5351A_CLK0_CTRL, 0x4D);
        res = i2c.write_reg(clock_gen_i2c_address, SI5351A_CLK2_CTRL, 0x69);
        // Sets relevant bits of P1 divider setting
        res = i2c.write_reg(clock_gen_i2c_address, SI5351A_MS0_P1_UPPER, 0x05);

        /* Now we write the lower bits of Multisynth Parameter P2.
         * This updates all the divider values into the Multisynth block.
         * The other multisynth parameters are correct so no need to write them.
         */
        res = i2c.write_reg(clock_gen_i2c_address, SI5351A_MS0_P2_LOWER, 0x00);

        // Wait a bit for Multisynth output to settle.
        delay_microseconds(1000);

        /* Enable all the clock outputs now we've finished changing the settings.
         * This will output 24.576MHz on CLK0 to xcore
         */
        res = i2c.write_reg(clock_gen_i2c_address, SI5351A_OE_CTRL, 0xF8);
        break;
    }
}
