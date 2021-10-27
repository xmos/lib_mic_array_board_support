// Copyright (c) 2018-2019, XMOS Ltd, All rights reserved
// This software is available under the terms provided in LICENSE.txt.
#include <xs1.h>
#include <platform.h>
#include <xs1_su.h>
#include <xclib.h>
#include <string.h>
#include <stdlib.h>
#include "debug_print.h"
#include "i2c.h"

#define REGREAD(device_addr, reg, data)  {data = i_i2c[0].read_reg(device_addr, reg, i2c_res);}
#define REGWRITE(device_addr, reg, val) {i_i2c[0].write_reg(device_addr, reg, val);}

//I2C slave
on tile[1]: port p_scl = PORT_I2C_SCL;
on tile[1]: port p_sda = PORT_I2C_SDA;

#define DEVICE_ADDRESS  0x20
#define MUTE_BUTTON     0x01
#define VOL_DOWN_BUTTON 0x02
#define ACTION_BUTTON   0x04
#define VOL_UP_BUTTON   0x08

void test_buttons()
{
    i2c_master_if i_i2c[1];

    par {
        [[distribute]] i2c_master(i_i2c, 1, p_scl, p_sda, 100);
        {
            unsigned char data = 0;
            i2c_regop_res_t i2c_res;
            int op = 0xFF;
            int detected_press = 0;
            int mic_mute = 0;
            int num_presses[4] = {0};
            int all_buttons_pressed = 0;

            debug_printf("Press all the four buttons sequentially\n");

            while(1)
            {
                detected_press = 0;
                REGREAD(DEVICE_ADDRESS, 0, op);
                if(op == 0) {
                    debug_printf("Error: Cannot read register\n");
                    debug_printf("FAIL\n");
                    exit(2);
                }

                if((op & VOL_UP_BUTTON) == 0)
                {
                    debug_printf("Volume Up button pressed\n");
                    detected_press = 1;
                    num_presses[0] += 1;
                }
                if((op & VOL_DOWN_BUTTON) == 0)
                {
                    debug_printf("Volume Down button pressed\n");
                    detected_press = 1;
                    num_presses[1] += 1;
                }
                if((op & ACTION_BUTTON) == 0)
                {
                    debug_printf("Action button pressed\n");
                    detected_press = 1;
                    num_presses[2] += 1;
                }
                if((op & MUTE_BUTTON) == 0)
                {
                    debug_printf("Mute button pressed\n");
                    detected_press = 1;
                    int config;
                    REGREAD(DEVICE_ADDRESS, 6, config);
                    num_presses[3] += 1;
                    if(mic_mute == 0)
                    {
                        config &= 0xef; //set bit 4(mic_off) of config0 to 0
                        mic_mute = 1;
                    }
                    else
                    {
                        config |= 0x10; //set bit 4(mic_off) of config0 to 1
                        mic_mute = 0;
                    }
                    REGWRITE(DEVICE_ADDRESS, 6, config)
                    
                }
                //wait_for_button_release
                if(detected_press == 1)
                {
                    do
                    {
                        REGREAD(DEVICE_ADDRESS, 0, op);
                    }while(((op & VOL_UP_BUTTON) == 0) || ((op & VOL_DOWN_BUTTON) == 0) || ((op & ACTION_BUTTON) == 0) || ((op & MUTE_BUTTON) == 0));
                }
                //check if all buttons have been pressed atleast once
                all_buttons_pressed = 1;
                for(int i=0; i<4; i++)
                {
                    if(num_presses[i] == 0)
                    {
                        all_buttons_pressed = 0;
                        break;
                    }
                }
                if(all_buttons_pressed == 1)
                {
                    op = 0xFF;
                    debug_printf("Check if LED is on and press mute button again to exit the test\n");

                    op = 0xFF;
                    while ((op & MUTE_BUTTON) != 0){
                        REGREAD(DEVICE_ADDRESS, 0, op);
                    };
                    int config = 0x10; //set bit 4(mic_off) of config0 to 1
                    REGWRITE(DEVICE_ADDRESS, 6, config)

                    debug_printf("PASS\n");
                    exit(0);
                }

                for(int i=0; i<4; i++)
                {
                    if(num_presses[i] >= 4)
                    {
                        debug_printf("Error: Button pressed more than 4 times\n");
                        debug_printf("FAIL\n");
                        exit(1);
                    }
                }

            }
            
            // Shutdown
            i_i2c[0].shutdown();
        }
    } /* par */

}


int main()
{
        par{
            on tile[1]:test_buttons();
        }
    return 0;
}
