// Copyright (c) 2018-2019, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <platform.h>
#include <xs1_su.h>
#include <xclib.h>
#include <string.h>
#include <stdlib.h>
#include "debug_print.h"
#include "i2c.h"

port p_spi_cs_n = on tile[0] : XS1_PORT_1A;
port p_spi_clk = on tile[0] : XS1_PORT_1C;
port p_spi_mosi = on tile[0] : XS1_PORT_1D;
port p_spi_miso = on tile[0] : XS1_PORT_1E;

#define P_SPI_CS_N_BIT  (0)
#define P_SPI_CLK_BIT   (1)
#define P_SPI_MOSI_BIT  (2)
#define P_SPI_MISO_BIT  (3)
#define BIT_SHIFT(x) (1<<x)


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
                    debug_printf("Seen 1000 transitions on port SPI_CS_N\n");
                    run = run&~(BIT_SHIFT(P_SPI_CS_N_BIT));
                }
               break;
            case p_spi_clk when pinsneq(val_spi_clk) :> val_spi_clk:

                idx_spi_clk++;
                if(idx_spi_clk == 1000) {
                    debug_printf("Seen 1000 transitions on port SPI_CLK\n");
                    run = run&~(BIT_SHIFT(P_SPI_CLK_BIT)); 
                }
               break;

            case p_spi_mosi when pinsneq(val_spi_mosi) :> val_spi_mosi:
                idx_spi_mosi++;
                if(idx_spi_mosi == 1000) {
                    debug_printf("Seen 1000 transitions on port SPI_MOSI\n");
                    run = run&~(BIT_SHIFT(P_SPI_MOSI_BIT)); 
                }
               break;
            case p_spi_miso when pinsneq(val_spi_miso) :> val_spi_miso:
                idx_spi_miso++;
                if(idx_spi_miso == 1000) {
                    debug_printf("Seen 1000 transitions on port SPI_MISO\n");
                    run = run&~(BIT_SHIFT(P_SPI_MISO_BIT)); 
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
    } else {
        if (run&BIT_SHIFT(P_SPI_CS_N_BIT)) {
            debug_printf("Error: port SPI_CS_N has not received data");
        }
        if (run&BIT_SHIFT(P_SPI_CLK_BIT)) {
            debug_printf("Error: port SPI_CLK has not received data");
        }
        if (run&BIT_SHIFT(P_SPI_MOSI_BIT)) {
            debug_printf("Error: port SPI_MOSI has not received data");
        }
        if (run&BIT_SHIFT(P_SPI_MISO_BIT)) {
            debug_printf("Error: port SPI_MISO has not received data");
        }

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
