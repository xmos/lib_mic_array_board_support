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

#define DEVICE_ADDRESS 0x68

void test_led()
{
    i2c_master_if i_i2c[1];

    par {
        [[distribute]] i2c_master(i_i2c, 1, p_scl, p_sda, 100);
        {
            // Set Shutdown Register to normal operatiom // All channel enable
            REGWRITE(DEVICE_ADDRESS, 0x00, 0x20);
            // Set current Setting Register 0x03 to its minimum value (5 mA)
            REGWRITE(DEVICE_ADDRESS, 0x03, 0x10);

            while(1) {

                // Set PWM register (OUT1-OUT3) to blue
                REGWRITE(DEVICE_ADDRESS, 0x04, 0x16);
                REGWRITE(DEVICE_ADDRESS, 0x05, 0x01);
                REGWRITE(DEVICE_ADDRESS, 0x06, 0x01);
                REGWRITE(DEVICE_ADDRESS, 0x07, 0x00);

                delay_milliseconds(500);

                // Set PWM register (OUT1-OUT3) to red
                REGWRITE(DEVICE_ADDRESS, 0x04, 0x01);
                REGWRITE(DEVICE_ADDRESS, 0x05, 0x01);
                REGWRITE(DEVICE_ADDRESS, 0x06, 0x16);
                REGWRITE(DEVICE_ADDRESS, 0x07, 0x00);

                delay_milliseconds(500);

            }
            // Shutdown
            i_i2c[0].shutdown();
        }
    } /* par */

}


int main()
{
        par{
            on tile[1]:test_led();
        }
    return 0;
}
