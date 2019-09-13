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

#define MAX_TRANSITIONS             ( 1000 )
#define EXP_SPI_CS_N_TRANSITIONS    ( MAX_TRANSITIONS )
#define EXP_SPI_CLK_TRANSITIONS     ( MAX_TRANSITIONS/2 )
#define EXP_SPI_MOSI_TRANSITIONS    ( MAX_TRANSITIONS/4 )
#define EXP_SPI_MISO_TRANSITIONS    ( MAX_TRANSITIONS/8 )


//#include "print.h"
int test_spi_ports()
{
    int val_spi_cs_n = 0;
    int val_spi_clk = 0;
    int val_spi_mosi = 0;
    int val_spi_miso = 0;
    int cnt_spi_cs_n = 0;
    int cnt_spi_clk = 0;
    int cnt_spi_mosi = 0;
    int cnt_spi_miso = 0;

    timer t;
    int y = 0;
    t :> y;
    int run = 1;
    int ret = 0;

    while (run) {
        select{
            case p_spi_cs_n when pinsneq(val_spi_cs_n) :> val_spi_cs_n:
                cnt_spi_cs_n++;
                if(cnt_spi_cs_n == MAX_TRANSITIONS) {
                    debug_printf("Seen %d transitions on port SPI_CS_N\n", cnt_spi_cs_n);
                    run = 0;
                }
               break;
            case p_spi_clk when pinsneq(val_spi_clk) :> val_spi_clk:
                cnt_spi_clk++;
            break;

            case p_spi_mosi when pinsneq(val_spi_mosi) :> val_spi_mosi:
               cnt_spi_mosi++; 
               break;
            case p_spi_miso when pinsneq(val_spi_miso) :> val_spi_miso:
                cnt_spi_miso++;
                break;
            case t when timerafter(y + 1000000000) :> void : 
                y += 1000000000;
                if(y > 2000000000) 
                { 
                    debug_printf("Error: wrong number of transitions on port SPI_CS_N: %d\n", cnt_spi_cs_n);
                    ret = 1; 
                    run = 0;
                }
                break;
        }
    }
    if (cnt_spi_clk > (EXP_SPI_CLK_TRANSITIONS * 0.9) && cnt_spi_clk < (EXP_SPI_CLK_TRANSITIONS * 1.1)) {
        debug_printf("Seen %d transitions on port SPI_CLK\n", cnt_spi_clk);
    } else {
        debug_printf("Error: wrong number of transitions on port SPI_CLK: %d\n", cnt_spi_clk);
        ret = 1;
    }
    if (cnt_spi_mosi > (EXP_SPI_MOSI_TRANSITIONS * 0.9) && cnt_spi_mosi < (EXP_SPI_MOSI_TRANSITIONS * 1.1)) {
        debug_printf("Seen %d transitions on port SPI_MOSI\n", cnt_spi_mosi);
    } else {
        debug_printf("Error: wrong number of transitions on port SPI_MOSI: %d\n", cnt_spi_mosi);
        ret = 1;
    }
    if (cnt_spi_miso > (EXP_SPI_MISO_TRANSITIONS * 0.9) && cnt_spi_miso < (EXP_SPI_MISO_TRANSITIONS * 1.1)) {
        debug_printf("Seen %d transitions on port SPI_MISO\n", cnt_spi_miso);
    } else {
        debug_printf("Error: wrong number of transitions on port SPI_MISO: %d\n", cnt_spi_miso);
        ret = 1;
    }
    if (ret == 0) {
        debug_printf("PASS\n");
    } else {
        debug_printf("FAIL\n");
        exit(1);
    }
    return 0;
}

int main()
{
        par{
            on tile[0]:test_spi_ports();
        }
    return 0;
}
