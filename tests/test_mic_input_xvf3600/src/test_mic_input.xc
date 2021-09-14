// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <string.h>
#include <xclib.h>
#include <stdint.h>
#include "stdio.h"
#include <stdlib.h>
#include <math.h>

#include "mic_array.h"
#include "mic_array_board_support.h"

#define ALLOWED_DB_DIFFERENCE (6.0)        //Float in dB
#define LOGGING               (1)           //Enable logging(verbose) output
#define NUMBER_OF_AVG_ITTERATIONS_LOG2 (10) //Controls the time to build up the spectrum

//If the decimation factor is changed the the coefs array of decimator_config must also be changed.
#define DECIMATION_FACTOR   6   //Corresponds to a 48kHz output sample rate
#define DECIMATOR_COUNT     2   //8 channels requires 2 decimators
#define FRAME_BUFFER_COUNT  3   //The minimum of 2 will suffice for this example

#define FRAME_LENGTH (1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2)
#define FFT_SINE_LUT dsp_sine_128
#define FFT_CHANNELS ((COUNT+1)/2)
#define ENABLE_PRECISION_MAXIMISATION 1

// App PLL setup
#define APP_PLL_CTL_BYPASS      0     // 0 = no bypass, 1 = bypass.
#define APP_PLL_CTL_INPUT_SEL   0     // 0 = XTAL, 1 = sysPLL
#define APP_PLL_CTL_ENABLE      1     // 0 = disabled, 1 = enabled.
#define APP_PLL_CTL_OD          4     // Output divider = (OD+1). OD valid from 0 to 7.
#define APP_PLL_CTL_F           511   // FB divider (PLL Multiplier) = (F+1)/2. F valid from 1 to 8191.
#define APP_PLL_CTL_R           4     // Ref divider = (R+1). R valid from 0 to 63.

// App PLL divider setup
#define APP_PLL_DIV_INPUT_SEL   1     // 0 = sysPLL, 1 = app_PLL
#define APP_PLL_DIV_DISABLE     0     // 1 = disabled (pin connected to X1D11), 0 = enabled divider output to pin.
#define APP_PLL_DIV_VALUE       9     // Divide by N+1 - remember there's a /2 also afterwards for 50/50 duty cycle.

// Fractional divide is M/N
#define APP_PLL_FRAC_EN             0   // 0 = disabled (do not use fractional feedback divider), 1 = enabled
#define APP_PLL_FRAC_NPLUS1_CYCLES  0   // M value is this reg value + 1.
#define APP_PLL_FRAC_TOTAL_CYCLES   0   // N value is this reg value + 1.

#define APP_PLL_CTL  ((APP_PLL_CTL_BYPASS << 29) | (APP_PLL_CTL_INPUT_SEL << 28) | (APP_PLL_CTL_ENABLE << 27) | (APP_PLL_CTL_OD << 23) | (APP_PLL_CTL_F << 8) | APP_PLL_CTL_R)
#define APP_PLL_DIV  ((APP_PLL_DIV_INPUT_SEL << 31) | (APP_PLL_DIV_DISABLE << 16) | APP_PLL_DIV_VALUE)
#define APP_PLL_FRAC ((APP_PLL_FRAC_EN << 31) | (APP_PLL_FRAC_NPLUS1_CYCLES << 8) | APP_PLL_FRAC_TOTAL_CYCLES)
on tile[0]: out port p_pdm_clk              = PORT_PDM_CLK;

on tile[0]: in buffered port:32 p_pdm_mics  = PORT_PDM_DATA;
on tile[0]: in port p_mclk                  = PORT_PDM_MCLK;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_2;

port p_rst_shared = on tile[0]: XS1_PORT_4F; // Bit 1: DAC_RST_N, Bit 2: SQ_nLIN, BIT 3: INT_N

int data[8][THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];

// Function to write the APP_PLL_CTL register in a clean way to ensure reliable operation.
// Need to pass in the tile number and desired register value.
void set_app_pll (tileref tile, int app_pll_ctl) {
  printf("Set app PLL\n");

  // Disable the PLL
  write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, (app_pll_ctl & 0xF7FFFFFF));
  // Enable the PLL to invoke a reset on the appPLL.
  write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, app_pll_ctl);
  // Must write the CTL register twice so that the F and R divider values are captured using a running clock.
  write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, app_pll_ctl);
  // Now disable and re-enable the PLL so we get the full 5us reset time with the correct F and R values.
  write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, (app_pll_ctl & 0xF7FFFFFF));
  write_node_config_reg(tile, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, app_pll_ctl);
  // Wait for PLL to lock.
  delay_microseconds(500);
}

void gen_app_pll_clk (void) {
  printf("APP_PLL_CTL is 0x%08X\n", APP_PLL_CTL);

  // We must first turn on the App PLL so subsequent clk divider reg writes work.
  set_app_pll(tile[0], APP_PLL_CTL);

  // Turn off the clock output
  write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_CLK_DIVIDER_NUM, (APP_PLL_DIV | 0x00010000));
  // Set the AppPLL frequency we want
  set_app_pll(tile[0], APP_PLL_CTL);
  // Set the fractional divider if used
  write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_PLL_FRAC_N_DIVIDER_NUM, APP_PLL_FRAC);
  // Wait for PLL output frequency to stabilise due to fractional divider enable
  delay_microseconds(100);
  // Turn on the clock output
  write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_CLK_DIVIDER_NUM, APP_PLL_DIV);
}

int your_favourite_window_function(unsigned i, unsigned window_length){
    return((int)((double)INT_MAX*sqrt(0.5*(1.0 - cos(2.0 * 3.14159265359*(double)i / (double)(window_length-2))))));
}

//This is here until lib_dsp is updated.
void dsp_bfp_shl2( dsp_complex_t pts[], const uint32_t N,
                   const int32_t shift_re, const int32_t shift_im );

void test(streaming chanend c_ds_output[DECIMATOR_COUNT]) {
    unsafe{
        unsigned buffer;
        memset(data, 0, sizeof(data));

        mic_array_frame_fft_preprocessed audio[FRAME_BUFFER_COUNT];

        int window[FRAME_LENGTH/2];
        for(unsigned i=0;i<FRAME_LENGTH/2;i++)
             window[i] = your_favourite_window_function(i, FRAME_LENGTH);

        mic_array_decimator_conf_common_t dcc = {
                MIC_ARRAY_MAX_FRAME_SIZE_LOG2,
                1, //dc removal
                1, //bit reversed indexing
                window,
                DECIMATION_FACTOR,
                g_third_stage_div_6_fir,
                0,
                FIR_COMPENSATOR_DIV_6,
                DECIMATOR_HALF_FRAME_OVERLAP,
                FRAME_BUFFER_COUNT};
        mic_array_decimator_config_t dc[2] = {
          {&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
          {&dcc, data[4], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };

        mic_array_decimator_configure(c_ds_output, DECIMATOR_COUNT, dc);

        mic_array_init_frequency_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        //This makes the test wait until the DC offset has settled down.
        for(unsigned i=0;i<128;i++)
            mic_array_get_next_frequency_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        int64_t subband_rms_power[COUNT][FRAME_LENGTH/2];
        memset(subband_rms_power, 0, sizeof(subband_rms_power));

        for(unsigned r=0;r<(1<<NUMBER_OF_AVG_ITTERATIONS_LOG2);r++){

            mic_array_frame_fft_preprocessed *  current =
                    mic_array_get_next_frequency_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

            int ch_headroom[COUNT] = {0};
#if ENABLE_PRECISION_MAXIMISATION
            for(unsigned channel_pairs=0;channel_pairs<(COUNT+1)/2;channel_pairs++){
                unsigned dec = (2*channel_pairs)/4;
                unsigned dec_ch = (2*channel_pairs) - dec*4;
                int im=0, re = clz(current->metadata[dec].sig_bits[dec_ch])-2;
                ch_headroom[2*channel_pairs] = re;

                if(2*channel_pairs+1 < COUNT){
                    im = clz(current->metadata[dec].sig_bits[dec_ch+1])-2;
                    ch_headroom[2*channel_pairs+1] = im;
                }
                dsp_bfp_shl2(current->data[channel_pairs], FRAME_LENGTH, re, im);
            }
#endif
            for(unsigned i=0;i<FFT_CHANNELS;i++){
                dsp_fft_forward(current->data[i], FRAME_LENGTH, FFT_SINE_LUT);
                dsp_fft_split_spectrum(current->data[i], FRAME_LENGTH);
            }

            mic_array_frame_frequency_domain * fd_frame = (mic_array_frame_frequency_domain*)current;

            for(unsigned ch=0;ch<COUNT;ch++){
                for (unsigned band=0;band < FRAME_LENGTH/2;band++){
                    int64_t power = (int64_t)fd_frame->data[ch][band].re *  (int64_t)fd_frame->data[ch][band].re +
                            (int64_t)fd_frame->data[ch][band].im * (int64_t)fd_frame->data[ch][band].im;
                    power >>= (NUMBER_OF_AVG_ITTERATIONS_LOG2 + (2*ch_headroom[ch]));
                    subband_rms_power[ch][band] += power;
                }
            }
        }

        //This can be used to restrict the bandwidth
        unsigned lower_bin = 1;//We never care about the DC and the NQ
        unsigned upper_bin = FRAME_LENGTH/2 ;

        double total_power = 0.0;
        for (unsigned band=1;band < FRAME_LENGTH/2;band++){
            for(unsigned ch_b=0;ch_b<COUNT;ch_b++){
                int64_t b = subband_rms_power[ch_b][band];
                double p = sqrt((double)b);

#if LOGGING
                printf("%.12f ", p);
#endif
                total_power += p;
            }
#if LOGGING
            printf("\n");
#endif
        }
        if(total_power < 10000.0){
            for(unsigned i=0;i<COUNT;i++){
                printf("Microphone %d absent\n", i);
            }
            printf("Fail: No microphones detected\n");
            _Exit(1);
        }

        double bin_count = (double)(upper_bin-lower_bin);
        double x_bar[COUNT] = {0};
        double xx_bar[COUNT] = {0};
        double xy_bar[COUNT][COUNT];
        memset(xy_bar, 0, sizeof(xy_bar));

        for (unsigned band=lower_bin;band < upper_bin;band++){

            double m[COUNT];
            for(unsigned ch=0;ch<COUNT;ch++){
                int64_t b = subband_rms_power[ch][band];
                m[ch] = sqrt((double)b);
                x_bar[ch] += m[ch];
                xx_bar[ch] += (m[ch]*m[ch]);
            }
            for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
                for(unsigned ch_b=ch_a + 1;ch_b<COUNT;ch_b++){
                    xy_bar[ch_a][ch_b] += (m[ch_a]*m[ch_b]);
                }
            }
        }

        for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
            x_bar[ch_a] /= bin_count;
            xx_bar[ch_a] /= bin_count;
            for(unsigned ch_b=ch_a + 1;ch_b<COUNT;ch_b++){
                xy_bar[ch_a][ch_b] /= bin_count;
            }
        }

        double sum_xx[COUNT] = {0};
        double sum_xy[COUNT][COUNT];
        memset(sum_xy, 0, sizeof(sum_xy));

        for (unsigned band=lower_bin;band < upper_bin;band++){

            double m[COUNT];
            for(unsigned ch=0;ch<COUNT;ch++){
                int64_t b = subband_rms_power[ch][band];
                m[ch] = sqrt((double)b);
            }

            for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
                double a = m[ch_a];
                sum_xx[ch_a] += ((a-x_bar[ch_a])*(a-x_bar[ch_a]));

                for(unsigned ch_b=ch_a + 1;ch_b<COUNT;ch_b++){
                    double b = m[ch_b];
                    sum_xy[ch_a][ch_b] += ((a-x_bar[ch_a])*(b-x_bar[ch_b]));
                }
            }
        }

#define DB_BIG 1000.0

        //This is for tracking the failing pairs.
        //In the end the broken one(s) should have the highest failure rate.
        unsigned mic_failed[COUNT] = {0};
        unsigned failure_count = 0;

        double max_db_diff = -DB_BIG;
        double min_r = DB_BIG, max_r = -DB_BIG;

        for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
            for(unsigned ch_b=ch_a + 1;ch_b<COUNT;ch_b++){
                double beta = sum_xy[ch_a][ch_b] / sum_xx[ch_a];
                double beta_db;
                if(beta > 0.0){
                    beta_db = 20*log10(beta);
                } else {
                    beta_db = -DB_BIG;
                }
                beta_db = fabs(beta_db);
                max_db_diff = fmax(max_db_diff, beta_db);

                if(beta_db > ALLOWED_DB_DIFFERENCE){
                    mic_failed[ch_a]++;
                    mic_failed[ch_b]++;
                    failure_count += 2;
                }
#if LOGGING
                printf("%u->%u beta:%fdb = %f\n", ch_a, ch_b, beta_db, beta);
#endif
            }
        }

        double mic_corellation[COUNT] = {0};

        for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
            for(unsigned ch_b=ch_a + 1;ch_b<COUNT;ch_b++){
                double r = (xy_bar[ch_a][ch_b] - x_bar[ch_a]*x_bar[ch_b]) /
                        sqrt((xx_bar[ch_a] - x_bar[ch_a]*x_bar[ch_a]) *
                                (xx_bar[ch_b] - x_bar[ch_b]*x_bar[ch_b]));
#if LOGGING
                printf("%u->%u  r: %f\n", ch_a, ch_b, r);
#endif
                mic_corellation[ch_a] += r;
                mic_corellation[ch_b] += r;
            }
        }

        for(unsigned i=0;i<COUNT;i++){
#if LOGGING
            printf("mic %u r: %f\n", i, mic_corellation[i]);
#endif
            if(mic_corellation[i] < ((float)(COUNT - 1)*0.8)){
                printf("Mic %u - uncorrelated\n", i);
            }
        }

        for(unsigned i=0;i<COUNT;i++){
            if ((failure_count>0) && mic_failed[i]){
                printf("Chance of failure for mic %d: %f\n", i,
                        100.0* (float)mic_failed[i] / (float)failure_count);
            } else{
                printf("Microphone %d working\n", i);
            }
        }

        double diff = max_db_diff;
        if(diff < ALLOWED_DB_DIFFERENCE){
            printf("Pass: %fdB spread\n", diff);
            _Exit(0);
        } else{
            printf("Fail: %fdB spread\n", diff);
            _Exit(1);
        }
    }
}

int main() {
    chan c_sync;
    par {
        on tile[0]: {

            // set microphone configuration
            #if (SQ_MIC_ARRAY == 1)
            p_rst_shared <: 0x4; // Keep DAC in reset (bit 1 low) and select square mic array (bit 3 high)
            #else
            p_rst_shared <: 0x0; // Keep DAC in reset (bit 1 low) and select linear mic array (bit 3 low)
            #endif
            gen_app_pll_clk();
            c_sync <: (int) 0;
            printf("Send sync token\n");
        }
        on tile[0]: {
            printf("Wait for sync token\n");
            c_sync :> int;
            printf("Received sync token\n");

            stop_clock(pdmclk);

            printf("Set up SDR\n");
            mic_array_setup_sdr(pdmclk, p_mclk, p_pdm_clk, p_pdm_mics, 8);

            streaming chan c_4x_pdm_mic[DECIMATOR_COUNT];
            streaming chan c_ds_output[DECIMATOR_COUNT];
            printf("Run test\n");
            par {
                mic_array_pdm_rx(p_pdm_mics, c_4x_pdm_mic[0], c_4x_pdm_mic[1]);
                mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[0], c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
                mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[1], c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);
                test(c_ds_output);
            }

        }

    }
    return 0;
}
