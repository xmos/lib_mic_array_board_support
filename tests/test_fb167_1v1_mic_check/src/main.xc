// Copyright (c) 2015-2021, XMOS Ltd, All rights reserved
// This software is available under the terms provided in LICENSE.txt.
#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "i2c.h"
#include "mic_array_board_support.h"

on tile[2]: out port p_pdm_clk            = XS1_PORT_1H;
on tile[2]: in buffered port:32 p_unused  = XS1_PORT_1F; // was 1K
on tile[2]: in port p_pdm_mics            = XS1_PORT_8B;
on tile[2]: in port p_mclk                = XS1_PORT_1G;
on tile[2]: clock mclk                    = XS1_CLKBLK_1;
on tile[2]: clock pdmclk                  = XS1_CLKBLK_2;
on tile[2]: port p_i2c					  = XS1_PORT_4F;

static void pdm_interface(in port p_pdm_mics, chanend c){

	c :> int;
	
    unsigned v;
    unsigned ones[8] = {0};

    timer t;
    unsigned time;

    configure_clock_src(mclk, p_mclk);
    configure_in_port(p_unused, mclk);
    start_clock(mclk);

    printf("Checking for Master Clock\n");
    unsigned now, then;
    t :> time;
    t:> then;
    int testing_mclk = 1;
    p_unused:> int;
#define CLOCK_COUNT 1000000
    while(testing_mclk){
        select {
            case t when timerafter(time + 100000000):> time:{
                printf("Time out on master clock\n");
                printf("Switching to internal clock\n");
                stop_clock(mclk);
                stop_clock(pdmclk);
                configure_clock_xcore(pdmclk, 16);
                configure_port_clock_output(p_pdm_clk, pdmclk);
                configure_in_port(p_pdm_mics, pdmclk);
                start_clock(pdmclk);

                testing_mclk = 0;
                break;
            }
            case p_unused:> int:{
                testing_mclk++;
                t :> time;
                if(testing_mclk == CLOCK_COUNT){
                    printf("Master clock present\n");
                    t:> now;
                    unsigned elapsed =  (now - then);
                    float t = (32.0*CLOCK_COUNT)/ (((float)elapsed)*10.0) * 1000.0;

                    printf("\t%fMHz\n", t);

                    if(t > 64.0){

                        printf("Failure: PLL clock too high\n");
                        delay_milliseconds(100);
                        _Exit(1);
                    }

                    stop_clock(mclk);
                    stop_clock(pdmclk);
                    configure_clock_src(mclk, p_mclk);
                    configure_clock_src_divide(pdmclk, p_mclk, 8);
                    configure_port_clock_output(p_pdm_clk, pdmclk);
                    configure_in_port(p_pdm_mics, pdmclk);
                    start_clock(mclk);
                    start_clock(pdmclk);
                    testing_mclk = 0;
                }
                break;
            }
        }
    }

    printf("\n");
    printf("Started PDM microphone test\n");
    delay_milliseconds(1000);

    unsigned mic_count = COUNT;

#define N (1<<24)
    for(unsigned n=0;n<N;n++){
        p_pdm_mics:> v;
        for(unsigned i=0;i<mic_count;i++){
            if(v&1) ones[i]++;
            v=v>>1;
        }
    }

    unsigned long long avg = 0;
    for(unsigned i=0;i<mic_count;i++)
        avg += ones[i];
    avg /= mic_count;

    int broken[8] = {0};

    printf("mic :   ones    :  zeros  :  delta\n");
    for(int i=0;i<mic_count;i++){
        double delta = 20.0 * log10((double) ones[i] / (double)avg);
        printf("%d: %10d %10d    %fdB\n",i, ones[i], N - ones[i], delta);
        if(abs(delta > 6.0)){
            printf("%d broken - out of spec\n", i);
            broken[i] = 1;
        }
    }

    for(unsigned i=0;i<mic_count;i++){
        if(ones[i] == N){
            if(!broken[i])
                printf("%d broken - tied high\n", i);
            broken[i] = 1;
        }
        if(ones[i] == 0){
            if(!broken[i])
                printf("%d broken - tied low\n", i);
            broken[i] = 1;
        }
    }

    int any_broken = 0;
    for(unsigned i=0;i<mic_count;i++)
        any_broken |= broken[i];

    if(any_broken){
        printf("Failure\n");
        delay_milliseconds(100);
        _Exit(1);
    } else {
        printf("Success\n");
        delay_milliseconds(100);
        _Exit(0);
    }

}

int main(){

	chan c;
	i2c_master_if i_i2c[1];
	
    par{
		on tile[2] : i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
        on tile[2]: {
            mabs_init_pll(i_i2c[0], WIFI_MIC_ARRAY);
            delay_seconds(2);
            c <: 1;
        }		
        on tile[2]: {
            pdm_interface(p_pdm_mics, c);
        }
    }
    return 0;
}
