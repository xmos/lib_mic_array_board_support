#include "mic_array_board_support.h"

#ifdef MIC_BOARD_LED_STCP

out port p_led_stcp = MIC_BOARD_LED_STCP;
out port p_led_shcp = MIC_BOARD_LED_SHCP;
out port p_led_data = MIC_BOARD_LED_DATA;

#define MAX(a,b) ((a) > (b) ? (a) : (b))

#define LED_COUNT MIC_BOARD_SUPPORT_LED_COUNT

/*
 * Timing data from:
 * https://assets.nexperia.com/documents/data-sheet/74HC_HCT595.pdf
 *
 * Hold times are negligible (less than 1 tick)
 */

/*
 * The chip is really powered at 3.3V. The values for 4.5V
 * seem to work fine, at least at room temperature.
 */
#define VCC 4

#if VCC==2
/*
 * Assuming Vcc = 2V, -40C to 85C
 */
#define T_DS_SHCP_SU    7    /* min setup time for DS before SHCP high */
#define T_SHCP_Q7S_PD  20    /* max SHCP to Q7S propagation delay */
#define T_CLK_PW       10    /* min pulse width for STCP and SHCP */
#define T_CLK_PERIOD   21    /* min clock period for SHCP */
#define T_SHCP_STCP_SU 10    /* min setup time for SHCP before SCTP high */

#elif VCC==4
/*
 * Assuming Vcc = 4.5V, -40C to 85C
 */
#define T_DS_SHCP_SU    2    /* min setup time for DS before SHCP high */
#define T_SHCP_Q7S_PD   5    /* max SHCP to Q7S propagation delay */
#define T_CLK_PW        2    /* min pulse width for STCP and SHCP */
#define T_CLK_PERIOD    5    /* min clock period for SHCP */
#define T_SHCP_STCP_SU  2    /* min setup time for SHCP before SCTP high */

#endif

/* calculate minimum time that SHCP must be low for between high pulses */
#define T_SHCP_LOW    (MAX(T_CLK_PERIOD, (T_SHCP_Q7S_PD + T_DS_SHCP_SU)) - T_CLK_PW)

static void wait_ticks(int ticks)
{
  timer tmr;
  uint32_t t;
  tmr :> t;
  tmr when timerafter(t+ticks-1) :> void;
}

/***************************************************************
Numbers are for the VCC=2V, -40C to 85C case.

shcp high for 10 ticks
shcp low for 17 ticks
ds change 7 ticks before clock high
ds changes every 27 ticks

                     270           100      170
              <----------------><-------><------->
               ________          ________          _______
shcp   _______|        |________|        |________|       ...

           70 (setup time)   70
          <-->              <-->
       __  ________________  ________________  ___________
ds     __/\________________\/________________/\___________...

                    200      70    (200ns is clk high to q7s valid, 70ns is setup time)
              <------------><-->
      _____________________  _________________  __________
q7s   _____________________/\_________________\/__________...

***************************************************************/

static void led_driver(out port stcp, out port shcp, out port data, uint16_t led_value)
{
  stcp <: 0;
  shcp <: 0;
  data <: 0;

  data <: (uint32_t)led_value >> LED_COUNT-1;
  wait_ticks(T_DS_SHCP_SU);
  shcp <: 1;

  for (int i = 0; i < LED_COUNT-1; i++) {
    wait_ticks(T_CLK_PW);
    shcp <: 0;
    wait_ticks(T_SHCP_LOW - T_DS_SHCP_SU);

    /* left shift led_value out (MSB first) */
    led_value <<= 1;
    data <: (uint32_t)led_value >> LED_COUNT-1;
    wait_ticks(T_DS_SHCP_SU);
    shcp <: 1;
  }

  wait_ticks(T_SHCP_STCP_SU);
  stcp <: 1;
  wait_ticks(T_CLK_PW);
  shcp <: 0;
  stcp <: 0;
}

[[combinable]]
void ma_bga167_led_driver(server interface ma_bga167_led_if leds)
{
    while (1) {
        select {
        case leds.set_leds(uint16_t led_value):
            led_driver(p_led_stcp, p_led_shcp, p_led_data, led_value);
            break;
        }
    }
}

#endif

