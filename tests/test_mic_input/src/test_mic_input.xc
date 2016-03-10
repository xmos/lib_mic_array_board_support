// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <string.h>
#include <xclib.h>
#include <stdint.h>
#include "stdio.h"
#include <stdlib.h>

#include "i2c.h"
#include "mic_array.h"
#include "mic_array_board_support.h"


//If the decimation factor is changed the the coefs array of decimator_config must also be changed.
#define DECIMATION_FACTOR   2   //Corresponds to a 48kHz output sample rate
#define DECIMATOR_COUNT     2   //8 channels requires 2 decimators
#define FRAME_BUFFER_COUNT  2   //The minimum of 2 will suffice for this example

on tile[0]:p_leds leds = DEFAULT_INIT;

on tile[0]:in port p_buttons =  XS1_PORT_4A;

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;


int data[8][THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];

void test(streaming chanend c_ds_output[DECIMATOR_COUNT],
        client interface led_button_if lb) {

    printf("Test started\n");


    unsafe{
        unsigned buffer;
        memset(data, 0, 8*THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR*sizeof(int));

        mic_array_frame_time_domain audio[FRAME_BUFFER_COUNT];

        mic_array_decimator_config_common dcc = {0, 1, 0, 0, DECIMATION_FACTOR,
               g_third_stage_div_2_fir, 0, FIR_COMPENSATOR_DIV_2,
               DECIMATOR_NO_FRAME_OVERLAP, FRAME_BUFFER_COUNT};
        mic_array_decimator_config dc[2] = {
          {&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
          {&dcc, data[4], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };

        mic_array_decimator_configure(c_ds_output, DECIMATOR_COUNT, dc);

        mic_array_init_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        long long avg [7] = {0};

#define REPS (128)

        for(unsigned r=0;r<REPS;r++){

            mic_array_frame_time_domain *  current =
                               mic_array_get_next_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);


            for(unsigned m=0;m<7;m++){
                long long energy = 0;
                for(unsigned s=0;s<(1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2);s++){

                    long long v = current->data[m][s];
                    v=v>>(MIC_ARRAY_MAX_FRAME_SIZE_LOG2/2);
                    energy += (v*v);
                }
                avg[m] += (energy/REPS);
            }

        }

        long long overall_average = 0;

        for(unsigned m=0;m<7;m++)
            overall_average += (avg[m]/7);


        int all_work = 0;
        for(unsigned m=0;m<7;m++){
            if((overall_average/avg[m]) < 2){

            } else {
                all_work = 1;
            }
        }
        if(all_work == 0)
            printf("All microphones working\n");
        else
            printf("At least one microphone broken\n");
        delay_milliseconds(100);
        _Exit(all_work);
    }
}

port p_i2c = on tile[1]: XS1_PORT_4E; // Bit 0: SCLK, Bit 1: SDA

void init_cs2100(client i2c_master_if i2c){

    #define CS2100_DEVICE_CONFIG_1      0x03
    #define CS2100_GLOBAL_CONFIG        0x05
    #define CS2100_FUNC_CONFIG_1        0x16
    #define CS2100_FUNC_CONFIG_2        0x17

    i2c_regop_res_t res;
    res = i2c.write_reg(0x9c>>1, CS2100_DEVICE_CONFIG_1, 0);
    res = i2c.write_reg(0x9c>>1, CS2100_GLOBAL_CONFIG, 0);
    res = i2c.write_reg(0x9c>>1, CS2100_FUNC_CONFIG_1, 0);
    res = i2c.write_reg(0x9c>>1, CS2100_FUNC_CONFIG_2, 0);
}

int main() {

    i2c_master_if i_i2c[1];
    par {
        on tile[1]:init_cs2100(i_i2c[0]);

        on tile[1]:[[distribute]]i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
        on tile[0]:{
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            streaming chan c_4x_pdm_mic[DECIMATOR_COUNT];
            streaming chan c_ds_output[DECIMATOR_COUNT];

            interface led_button_if lb[1];

            par {
                button_and_led_server(lb, 1, leds, p_buttons);
                mic_array_pdm_rx(p_pdm_mics, c_4x_pdm_mic[0], c_4x_pdm_mic[1]);
                mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[0], c_ds_output[0]);
                mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[1], c_ds_output[1]);
                test(c_ds_output, lb[0]);
            }

        }

    }
    return 0;
}
