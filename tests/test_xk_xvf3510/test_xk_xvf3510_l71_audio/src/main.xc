// Copyright (c) 2018-2019, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <platform.h>
#include <xs1_su.h>
#include <xclib.h>
#include <string.h>
#include <stdlib.h>
#include "i2c.h"
#include "i2s.h"
#include "dsp_fft.h"
#include "math.h"
#include <stdio.h>
#define DAC3101_I2C_DEVICE_ADDR 0x18
#define I2CEXP_I2C_DEVICE_ADDR  0x20

// TLV320DAC3101 Register Addresses
// Page 0
#define DAC3101_PAGE_CTRL     0x00 // Register 0 - Page Control
#define DAC3101_SW_RST        0x01 // Register 1 - Software Reset
#define DAC3101_CLK_GEN_MUX   0x04 // Register 4 - Clock-Gen Muxing
#define DAC3101_PLL_P_R       0x05 // Register 5 - PLL P and R Values
#define DAC3101_PLL_J         0x06 // Register 6 - PLL J Value
#define DAC3101_PLL_D_MSB     0x07 // Register 7 - PLL D Value (MSB)
#define DAC3101_PLL_D_LSB     0x08 // Register 8 - PLL D Value (LSB)
#define DAC3101_NDAC_VAL      0x0B // Register 11 - NDAC Divider Value
#define DAC3101_MDAC_VAL      0x0C // Register 12 - MDAC Divider Value
#define DAC3101_DOSR_VAL_LSB  0x0E // Register 14 - DOSR Divider Value (LS Byte)
#define DAC3101_CLKOUT_MUX    0x19 // Register 25 - CLKOUT MUX
#define DAC3101_CLKOUT_M_VAL  0x1A // Register 26 - CLKOUT M_VAL
#define DAC3101_CODEC_IF      0x1B // Register 27 - CODEC Interface Control
#define DAC3101_BLOCK_SEL     0x3C // Register 60 - DAC Processing Block Selection

#define DAC3101_DAC_DAT_PATH  0x3F // Register 63 - DAC Data Path Setup
#define DAC3101_DAC_VOL       0x40 // Register 64 - DAC Vol Control
#define DAC3101_DACL_VOL_D    0x41 // Register 65 - DAC Left Digital Vol Control
#define DAC3101_DACR_VOL_D    0x42 // Register 66 - DAC Right Digital Vol Control
#define DAC3101_GPIO1_IO      0x33 // Register 51 - GPIO1 In/Out Pin Control

#define DAC3101_LEFT_BEEP_GEN 0x47 // Register 71 - Left Beep Generator
#define DAC3101_BEEP_LEN_MSB  0x49 // Register 73 - Beep Length MSB
#define DAC3101_BEEP_LEN_MID  0x4A // Register 74 - Beep Length Middle Bits
#define DAC3101_BEEP_LEN_LSB  0x4B // Register 75 - Beep Length LSB
#define DAC3101_BEEP_SIN_MSB  0x4C // Register 76 - Beep Sin(x) MSB
#define DAC3101_BEEP_SIN_LSB  0x4D // Register 77 - Beep Sin(x) LSB
#define DAC3101_BEEP_COS_MSB  0x4E // Register 78 - Beep Cos(x) MSB
#define DAC3101_BEEP_COS_LSB  0x4F // Register 79 - Beep Cos(x) LSB

// Page 1
#define DAC3101_HP_DRVR       0x1F // Register 31 - Headphone Drivers
#define DAC3101_SPK_AMP       0x20 // Register 32 - Class-D Speaker Amp
#define DAC3101_HP_DEPOP      0x21 // Register 33 - Headphone Driver De-pop
#define DAC3101_DAC_OP_MIX    0x23 // Register 35 - DAC_L and DAC_R Output Mixer Routing
#define DAC3101_HPL_VOL_A     0x24 // Register 36 - Analog Volume to HPL
#define DAC3101_HPR_VOL_A     0x25 // Register 37 - Analog Volume to HPR
#define DAC3101_SPKL_VOL_A    0x26 // Register 38 - Analog Volume to Left Speaker
#define DAC3101_SPKR_VOL_A    0x27 // Register 39 - Analog Volume to Right Speaker
#define DAC3101_HPL_DRVR      0x28 // Register 40 - Headphone Left Driver
#define DAC3101_HPR_DRVR      0x29 // Register 41 - Headphone Right Driver
#define DAC3101_SPKL_DRVR     0x2A // Register 42 - Left Class-D Speaker Driver
#define DAC3101_SPKR_DRVR     0x2B // Register 43 - Right Class-D Speaker Driver

#define DAC3101_REGREAD(reg, data)  {data = i_i2c[0].read_reg(DAC3101_I2C_DEVICE_ADDR, reg, i2c_res);}
#define DAC3101_REGWRITE(reg, val) {i_i2c[0].write_reg(DAC3101_I2C_DEVICE_ADDR, reg, val);}
#define I2EXP_REGREAD(reg, data)  {data = i_i2c[0].read_reg(I2CEXP_I2C_DEVICE_ADDR, reg, i2c_res);}
#define I2EXP_REGWRITE(reg, val) {i_i2c[0].write_reg(I2CEXP_I2C_DEVICE_ADDR, reg, val);}

//I2S slave
on tile[0]: in port p_mclk = PORT_PDM_MCLK;
on tile[0]: in port p_bclk = PORT_I2S_BCLK;

on tile[0]: clock mclk = XS1_CLKBLK_1;
on tile[0]: clock bclk = XS1_CLKBLK_2;
on tile[0]: in buffered port:32 p_din[1] = {I2S_DATA_IN};
on tile[0]: out buffered port:32 p_dout[1] = {I2S_MIC_DATA};
on tile[0]: in buffered port:32 p_lrclk = PORT_I2S_LRCLK;

#define SAMPLE_FREQUENCY 48000
#define MASTER_CLOCK_FREQUENCY_48 24576000
#define MASTER_CLOCK_FREQUENCY_44_1 22579200
#define FFT_LENGTH 1024
// generate a 1.5kHz sinewave for 10 seconds
#define SIN_COEFF 0x18F9
#define COS_COEFF 0x7D8A
#define BEEP_LENGTH 0x75300

#define MIN_SNR_DB 30

on tile[1]: port p_scl = PORT_I2C_SCL;
on tile[1]: port p_sda = PORT_I2C_SDA;

void configure_dac()
{
    i2c_master_if i_i2c[1];

    par {
        [[distribute]] i2c_master(i_i2c, 1, p_scl, p_sda, 100);
        {
            unsigned char data = 0;
            i2c_regop_res_t i2c_res;
            // Wait
            delay_milliseconds(400); //give tile0 enough time to bring dac out of reset
            // Set register page to 0
            DAC3101_REGWRITE(DAC3101_PAGE_CTRL, 0x00);
            // Initiate SW reset (PLL is powered off as part of reset)
            DAC3101_REGWRITE(DAC3101_SW_RST, 0x01);
            // so I've got 24MHz in to PLL, I want 24.576MHz or 22.5792MHz out.
            
            // I will always be using fractional-N (D != 0) so we must set R = 1
            // PLL_CLKIN/P must be between 10 and 20MHz so we must set P = 2
            
            // PLL_CLK = CLKIN * ((RxJ.D)/P)
            // We know R = 1, P = 2.
            // PLL_CLK = CLKIN * (J.D / 2)
                        
            // For 24.576MHz:
            // J = 8
            // D = 1920
            // So PLL_CLK = 24 * (8.192/2) = 24 x 4.096 = 98.304MHz
            // Then:
            // NDAC = 4
            // MDAC = 4
            // DOSR = 128
            // So:
            // DAC_CLK = PLL_CLK / 4 = 24.576MHz.
            // DAC_MOD_CLK = DAC_CLK / 4 = 6.144MHz.
            // DAC_FS = DAC_MOD_CLK / 128 = 48kHz.
            
            // For 22.5792MHz:
            // J = 7
            // D = 5264
            // So PLL_CLK = 24 * (7.5264/2) = 24 x 3.7632 = 90.3168MHz
            // Then:
            // NDAC = 4
            // MDAC = 4
            // DOSR = 128
            // So:
            // DAC_CLK = PLL_CLK / 4 = 22.5792MHz.
            // DAC_MOD_CLK = DAC_CLK / 4 = 5.6448MHz.
            // DAC_FS = DAC_MOD_CLK / 128 = 44.1kHz.
            
            // This setup is for 3.072MHz in, 24.576MHz out.
            // We want PLLP = 1, PLLR = 4, PLLJ = 8, PLLD = 0, MDAC = 4, NDAC = 4, DOSR = 128
             // Set PLL J Value to 7
            DAC3101_REGWRITE(DAC3101_PLL_J, 0x08);
            // Set PLL D to 0 ...
            // Set PLL D MSB Value to 0x00
            DAC3101_REGWRITE(DAC3101_PLL_D_MSB, 0x00);
            // Set PLL D LSB Value to 0x00
            DAC3101_REGWRITE(DAC3101_PLL_D_LSB, 0x00);

            delay_milliseconds(1);
            
            // Set PLL_CLKIN = BCLK (device pin), CODEC_CLKIN = PLL_CLK (generated on-chip)
            DAC3101_REGWRITE(DAC3101_CLK_GEN_MUX, 0x07);
            
            // Set PLL P and R values and power up.
            DAC3101_REGWRITE(DAC3101_PLL_P_R, 0x94);

            // Set NDAC clock divider to 4 and power up.
            DAC3101_REGWRITE(DAC3101_NDAC_VAL, 0x84);
            // Set MDAC clock divider to 4 and power up.
            DAC3101_REGWRITE(DAC3101_MDAC_VAL, 0x84);
            // Set OSR clock divider to 128.
            DAC3101_REGWRITE(DAC3101_DOSR_VAL_LSB, 0x80);
            
            // Set CLKOUT Mux to DAC_CLK
            DAC3101_REGWRITE(DAC3101_CLKOUT_MUX, 0x04);
            // Set CLKOUT M divider to 1 and power up.
            DAC3101_REGWRITE(DAC3101_CLKOUT_M_VAL, 0x81);
            // Set GPIO1 output to come from CLKOUT output.
            DAC3101_REGWRITE(DAC3101_GPIO1_IO, 0x10);
            
            // Set CODEC interface mode: I2S, 24 bit, slave mode (BCLK, WCLK both inputs).
            DAC3101_REGWRITE(DAC3101_CODEC_IF, 0x20);
            // Set register page to 1
            DAC3101_REGWRITE(DAC3101_PAGE_CTRL, 0x01);
            // Program common-mode voltage to mid scale 1.65V.
            DAC3101_REGWRITE(DAC3101_HP_DRVR, 0x14);
            // Program headphone-specific depop settings.
            // De-pop, Power on = 800 ms, Step time = 4 ms
            DAC3101_REGWRITE(DAC3101_HP_DEPOP, 0x4E);
            // Program routing of DAC output to the output amplifier (headphone/lineout or speaker)
            // LDAC routed to left channel mixer amp, RDAC routed to right channel mixer amp
            DAC3101_REGWRITE(DAC3101_DAC_OP_MIX, 0x44);
            // Unmute and set gain of output driver
            // Unmute HPL, set gain = 0 db
            DAC3101_REGWRITE(DAC3101_HPL_DRVR, 0x06);
            // Unmute HPR, set gain = 0 dB
            DAC3101_REGWRITE(DAC3101_HPR_DRVR, 0x06);
            // Unmute Left Class-D, set gain = 12 dB
            DAC3101_REGWRITE(DAC3101_SPKL_DRVR, 0x0C);
            // Unmute Right Class-D, set gain = 12 dB
            DAC3101_REGWRITE(DAC3101_SPKR_DRVR, 0x0C);
            // Power up output drivers
            // HPL and HPR powered up
            DAC3101_REGWRITE(DAC3101_HP_DRVR, 0xD4);
            // Power-up L and R Class-D drivers
            DAC3101_REGWRITE(DAC3101_SPK_AMP, 0xC6);
            // Enable HPL output analog volume, set = -9 dB
            DAC3101_REGWRITE(DAC3101_HPL_VOL_A, 0x92);
            // Enable HPR output analog volume, set = -9 dB
            DAC3101_REGWRITE(DAC3101_HPR_VOL_A, 0x92);
            // Enable Left Class-D output analog volume, set = -9 dB
            DAC3101_REGWRITE(DAC3101_SPKL_VOL_A, 0x92);
            // Enable Right Class-D output analog volume, set = -9 dB
            DAC3101_REGWRITE(DAC3101_SPKR_VOL_A, 0x92);
            
            delay_milliseconds(100);

            // Power up DAC
            // Set register page to 0
            DAC3101_REGWRITE(DAC3101_PAGE_CTRL, 0x00);
            // Power up DAC channels and set digital gain
            // Powerup DAC left and right channels (soft step enabled)
            DAC3101_REGWRITE(DAC3101_DAC_DAT_PATH, 0xD4);
            // DAC Left gain = 0dB
            DAC3101_REGWRITE(DAC3101_DACL_VOL_D, 0x00);
            // DAC Right gain = 0dB
            DAC3101_REGWRITE(DAC3101_DACR_VOL_D, 0x00);
            // Unmute digital volume control
            // Unmute DAC left and right channels
            DAC3101_REGWRITE(DAC3101_DAC_VOL, 0x00);
            delay_milliseconds(100);
            // Shutdown
            i_i2c[0].shutdown();


        }
    } /* par */
}
#define PEAK_BIN 32
void generate_sine() {    
    i2c_master_if i_i2c[1];

    par {
        [[distribute]] i2c_master(i_i2c, 1, p_scl, p_sda, 100);
        {

            i2c_regop_res_t i2c_res;

            DAC3101_REGWRITE(DAC3101_BLOCK_SEL, 0x19);
            DAC3101_REGWRITE(DAC3101_BEEP_LEN_MSB, BEEP_LENGTH>>16);
            DAC3101_REGWRITE(DAC3101_BEEP_LEN_MID, BEEP_LENGTH>>8);
            DAC3101_REGWRITE(DAC3101_BEEP_LEN_LSB, BEEP_LENGTH&0xFF);
            DAC3101_REGWRITE(DAC3101_BEEP_SIN_MSB, SIN_COEFF>>8);
            DAC3101_REGWRITE(DAC3101_BEEP_SIN_LSB, SIN_COEFF&0xFF);
            DAC3101_REGWRITE(DAC3101_BEEP_COS_MSB, COS_COEFF>>8);
            DAC3101_REGWRITE(DAC3101_BEEP_COS_LSB, COS_COEFF&0xFF);
            DAC3101_REGWRITE(DAC3101_LEFT_BEEP_GEN, 0x80);

            while (1) {
                DAC3101_REGWRITE(DAC3101_LEFT_BEEP_GEN, 0x80);
            }
            // Shutdown
            i_i2c[0].shutdown();
        }
    }
}

void create_i2s_slave(client i2s_callback_if i_i2s)
{
    configure_clock_src(mclk, p_mclk);
    start_clock(mclk);
    i2s_slave(i_i2s, p_dout, 1, p_din, 1, p_bclk, p_lrclk, bclk);
}

double compute_snr(dsp_complex_t* sig)
{
        dsp_fft_bit_reverse(sig, FFT_LENGTH);
        dsp_fft_forward(sig, FFT_LENGTH, dsp_sine_1024);
        dsp_fft_split_spectrum(sig, FFT_LENGTH);
        double peak = 0;
        double noise = 0;
        for (int i=1; i<FFT_LENGTH; i++) {
            double en = (double)(sig[i].re)*(double)(sig[i].re) + (double)(sig[i].im)*(double)(sig[i].im);
            if (i==PEAK_BIN) {
                peak = en;
            } else {
                noise += en;
            }        
        }
        double snr = 10*log10(peak/noise);
        printf("peak val %.2f, noise floor %.2f, SNR %.2f dB\n", peak, noise, snr);
        return snr;        
}

void i2s_process(server i2s_callback_if i2s)
{
  int32_t count = 0;
  dsp_complex_t sig[FFT_LENGTH];
  uint32_t right_samples[FFT_LENGTH];

  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_I2S;
      unsigned master_clock_freq = MASTER_CLOCK_FREQUENCY_48; 

      if ((SAMPLE_FREQUENCY % 11025) == 0)
      {
          master_clock_freq = MASTER_CLOCK_FREQUENCY_44_1;
      }
      i2s_config.mclk_bclk_ratio = (master_clock_freq/SAMPLE_FREQUENCY)/64;


      break;

    case i2s.receive(size_t index, int32_t in_samp):
      //printf("tile0: received sample 0x%x\n",in_samp);
      if(index == 0)
      {
          //chan0 <: in_samp;
          sig[count].re = in_samp;
          sig[count].im = 0;
      }
      else if(index == 1)
      {
          right_samples[count] = in_samp;
          count++;
      }
      double snr_left = 0;
      double snr_right = 0; 
      if (count==FFT_LENGTH) {
        snr_left = compute_snr(sig);
        for (int i=0; i<FFT_LENGTH; i++) {
            sig[i].re = right_samples[i];
        }
        snr_right = compute_snr(sig);
        if (snr_left<MIN_SNR_DB) {
            printf("Fail: Left SNR is below %ddB", MIN_SNR_DB);
            exit(1);
        } else if (snr_right<MIN_SNR_DB) {
            printf("Fail: Right SNR is below %ddB", MIN_SNR_DB);
            exit(2);
        } else {
            // success
            exit(0);
        }
      }
      break;

    case i2s.send(size_t index) -> int32_t sample:
        // do nothing
        break;

    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART; // Keep on looping
      break;
    }
  }
}

int main()
{  
    interface i2s_callback_if i_i2s;

    par{
        on tile[1]: {
            configure_dac();
            generate_sine();
        }
        on tile[0]: {
            delay_seconds(2);
            par{
                create_i2s_slave(i_i2s);
                i2s_process(i_i2s);
            }
        }
    }
    return 0;
}
