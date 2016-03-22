// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>

on tile[0]: out port p_pdm_clk            = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_unused  = XS1_PORT_1K;
on tile[0]: in port p_pdm_mics            = XS1_PORT_8B;
on tile[0]: in port p_mclk                = XS1_PORT_1F;
on tile[0]: clock mclk                    = XS1_CLKBLK_1;
on tile[0]: clock pdmclk                  = XS1_CLKBLK_2;

static void pdm_interface(in port p_pdm_mics){
    unsigned v;
    unsigned ones[8] = {0};
    unsigned zeros[8] = {0};
    unsigned count = 0;


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
    int broken[8] = {0};
    int tied_to_clock[8] = {0};
#define PASSES 5
    unsigned n=0;

    unsigned print_counter = 0;
    for(unsigned i=0;i<0xfffff;i++)
        p_pdm_mics:> v;

    while(1){
        for(unsigned i=0;i<8;i++){
            unsigned d = v&1;
            v=v>>1;
            if(d)
                ones[i]++;
            else
                zeros[i]++;
        }
        count++;
#define N (1<<13)

        if((count&(N-1)) == 0){
            for(unsigned i=0;i<7;i++){
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
                if(zeros[i] == N){
                    if(!broken[i])
                        printf("%d broken - tied low\n", i);
                    broken[i] = 1;
                }
                if(zeros[i] == 0){
                    if(!broken[i])
                        printf("%d broken - tied high\n", i);
                    broken[i] = 1;
                }
                if((ones[i] - N/2) <  16){
                    tied_to_clock[i]++;
                    if(tied_to_clock > 64){
                        if(!broken[i])
                            printf("%d broken - tied to clock\n", i);
                        broken[i] = 1;
                    }
                } else if((zeros[i] - N/2) <  16){
                    tied_to_clock[i]++;
                    if(tied_to_clock > 64){
                        if(!broken[i])
                            printf("%d broken - tied to clock\n", i);
                        broken[i] = 1;
                    }
                } else {
                    tied_to_clock[i]--;
                    if(tied_to_clock < 0)
                        tied_to_clock[i] = 0;
                }
               // printf("%d %8d %8d\n", i, ones[i], zeros[i]);
                ones[i]=0;
                zeros[i]=0;
                print_counter++;
                if(!(print_counter&0xff))
                        printf("Testing %d of %d\n", ++n, PASSES);



                if(n == PASSES){
                    int any_broken = 0;
                    for(unsigned i=0;i<8;i++)
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
            }
        }
        p_pdm_mics:> v;
        delay_ticks(v); //add pseudo random sampling
    }
}

int main(){

    par{
        on tile[0]: {
            pdm_interface(p_pdm_mics);
        }
    }
    return 0;
}
