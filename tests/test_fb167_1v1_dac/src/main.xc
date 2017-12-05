// Test of I2C and I2S connections to DAC
// Press button A to exit with status 0, button D to exit with status 1
#include <xs1.h>
#include <platform.h>
#include <limits.h>
#include <stdlib.h>
#include "debug_print.h"
#include "xassert.h"
#include "otp_board_info.h"
#include "i2c.h"
#include "i2s.h"
#include "sine.h"


#define I2S_TILE 2
// PDM clock and data
in port p_mclk_in2              = on tile[I2S_TILE]: XS1_PORT_1G;
port p_i2c						= on tile[2] : XS1_PORT_4F;
port p_dac_rst					= on tile[2] : XS1_PORT_4E; // bit 2: DAC0, bit 3: DAC1
#if DAC0
out buffered port:32 p_i2s_dout[1]  = on tile[I2S_TILE]: {XS1_PORT_1K}; // DAC0
#define RESET 0x7
#define I2C_ADDR 0x4A
#elif DAC1
out buffered port:32 p_i2s_dout[1]  = on tile[I2S_TILE]: {XS1_PORT_1J}; // DAC1
#define RESET 0xB
#define I2C_ADDR 0x4B
#endif
out buffered port:32 p_bclk         = on tile[I2S_TILE]: XS1_PORT_1M;
out buffered port:32 p_lrclk        = on tile[I2S_TILE]: XS1_PORT_1L;

clock mclk                          = on tile[I2S_TILE]: XS1_CLKBLK_3;
clock bclk                          = on tile[I2S_TILE]: XS1_CLKBLK_4;

in port p_buttons               = on tile[0]: XS1_PORT_4F;

#define OUTPUT_SAMPLE_RATE 48000
#define MASTER_CLOCK_FREQUENCY 24576000

[[distributable]]
void i2s_handler(server i2s_callback_if i2s,
                 client i2c_master_if i2c)
{

  p_dac_rst <: 0x0;
  delay_milliseconds(1);  
  
  int sine_count[2] = {0, 0};
  int sine_inc[2] = {0x080, 0x080};

  p_dac_rst <: RESET;
  delay_milliseconds(1);

  i2c_regop_res_t res;
  uint8_t data;
  int adr = I2C_ADDR;
  data = i2c.read_reg(adr, 0x01, res);
  debug_printf("I2C ID: %x, res: %d\n", data, res);
  xassert(data == 0xD9);

  data = i2c.read_reg(adr, 0x02, res);
  data |= 1;
  res = i2c.write_reg(adr, 0x02, data); // Power down

  // Setting MCLKDIV2 high if using 24.576MHz.
  data = i2c.read_reg(adr, 0x03, res);
  data |= 1;
  res = i2c.write_reg(adr, 0x03, data);

  data = 0b01110000;
  res = i2c.write_reg(adr, 0x10, data);

  data = i2c.read_reg(adr, 0x02, res);
  data &= ~1;
  res = i2c.write_reg(adr, 0x02, data); // Power up


  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      /* Configure the I2S bus */
      i2s_config.mode = I2S_MODE_LEFT_JUSTIFIED;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/OUTPUT_SAMPLE_RATE)/64;

      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      // This application never restarts the I2S bus
      restart = I2S_NO_RESTART;
      break;

    case i2s.receive(size_t index, int32_t sample):
      break;

    case i2s.send(size_t index) -> int32_t sample:
      sample = i2s_sine[sine_count[index]>>8];
      sine_count[index] += sine_inc[index];
      if (sine_count[index] >= 100 * 256) {
          sine_count[index] -= 100 * 256;
      }
      break;
    }
  }
};

#define BUTTON_PRESSED(but_mask, old_val, new_val) (((old_val) & (but_mask)) == (but_mask) && ((new_val) & (but_mask)) == 0)
#define BUTTON_DEBOUNCE_DELAY (20000000)

void button_chk(void) {

	int button_val;
	int buttons_active = 1;
	unsigned buttons_timeout;
	unsigned time;
	timer button_tmr;

	p_buttons :> button_val;
	
	while(1) {
		select
		{
		  case buttons_active => p_buttons when pinsneq(button_val) :> unsigned new_button_val:

			if BUTTON_PRESSED(1, button_val, new_button_val) {
			  debug_printf("Pressed Button A - tone heard - exitting now.\n");
			  exit(0);
			}	
		    if BUTTON_PRESSED(1<<3, button_val, new_button_val) {
			  debug_printf("Pressed Button D - no tone heard - exitting now\n");
			  exit(1);
			}
			if (!buttons_active)
			{
			  button_tmr :> buttons_timeout;
			  buttons_timeout += BUTTON_DEBOUNCE_DELAY;
			}
			button_val = new_button_val;
			break;
		  case !buttons_active => button_tmr when timerafter(buttons_timeout) :> void:
			buttons_active = 1;
			p_buttons :> button_val;
			break;
        }
	}

}

int main(void) {
	
	i2c_master_if i_i2c[1];
	i2s_callback_if i_i2s;
	
	par {
		on tile[2] : i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
		on tile[I2S_TILE]: {
		  configure_clock_src(mclk, p_mclk_in2);
		  start_clock(mclk);
		  i2s_master(i_i2s, p_i2s_dout, 1, null, 0, p_bclk, p_lrclk, bclk, mclk);
		}		
		on tile[I2S_TILE]: [[distribute]] i2s_handler(i_i2s, i_i2c[0]);
		on tile[0] : button_chk();
	}

	return 0;
}