// Copyright (c) 2018-2019, XMOS Ltd, All rights reserved
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
port p_spi_cs_n = on tile[0] : XS1_PORT_1A;
port p_spi_clk = on tile[0] : XS1_PORT_1C;
port p_spi_mosi = on tile[0] : XS1_PORT_1D;
port p_spi_miso = on tile[0] : XS1_PORT_1E;
//#include "print.h"
int test_spi_ports()
{
    int val_spi_cs_n = 0;
    int val_spi_clk = 0;
    int val_spi_mosi = 0;
    int val_spi_miso = 0;
    int idx_spi_cs_n = 0;
    int idx_spi_clk = 0;
    int idx_spi_mosi = 0;
    int idx_spi_miso = 0;

    timer t;
    int y = 0;
    t :> y;
    int run = 0x0F;
    int ret = 0;

    while (run) {
        select{
            case p_spi_cs_n when pinsneq(val_spi_cs_n) :> val_spi_cs_n:
                idx_spi_cs_n++;
                if(idx_spi_cs_n == 1000) {
                    debug_printf("Seen 1000 transitions on p_spi_cs_n\n");
                    run = run&~(0x01);
                }
               break;
            case p_spi_clk when pinsneq(val_spi_clk) :> val_spi_clk:

                idx_spi_clk++;
                if(idx_spi_clk == 1000) {
                    debug_printf("Seen 1000 transitions on p_spi_clk\n");
                    run = run&~(0x02); 
                }
               break;

            case p_spi_mosi when pinsneq(val_spi_mosi) :> val_spi_mosi:
                idx_spi_mosi++;
                if(idx_spi_mosi == 1000) {
                    debug_printf("Seen 1000 transitions on p_spi_mosi\n");
                    run = run&~(0x04); 
                }
               break;
            case p_spi_miso when pinsneq(val_spi_miso) :> val_spi_miso:
                idx_spi_miso++;
                if(idx_spi_miso == 1000) {
                    debug_printf("Seen 1000 transitions on p_spi_miso\n");
                    run = run&~(0x08); 
                }
                break;
            case t when timerafter(y + 1000000000) :> void : 
                y += 1000000000;
                if(y > 2000000000) 
                { 
                    debug_printf("Error: Not all transitions seen\n");
                    run = 0; 
                    ret = 1;
                }
                break;
        }
    }
    if (ret==0) {
        debug_printf("PASS\n");
    }
    return ret;
}


int main()
{
        par{
            on tile[0]:test_spi_ports();
        }
    return 0;
}
