#include "csr.h"
#include "interrupts.h"
#include "mmio.h"
#include "printf.h"

const uint32_t CLK_FREQ = 12e6;
const double TIME_PER_SYMBOL = 0.683;
const uint32_t CYCLES_PER_SYMBOL = CLK_FREQ * TIME_PER_SYMBOL;
const uint32_t FRAQ_BITS = 29;

#define SYMBOL_AMOUNT 162
uint8_t symbols[SYMBOL_AMOUNT] = {
    1, 1, 0, 2, 0, 2, 0, 0, 1, 0, 2, 0, 1, 1, 3, 0, 2, 0, 1, 0, 2, 3, 2, 3,
    1, 1, 1, 0, 0, 0, 0, 0, 2, 0, 1, 0, 0, 1, 2, 1, 2, 2, 2, 0, 0, 2, 3, 2,
    1, 3, 0, 2, 1, 3, 2, 3, 0, 2, 2, 3, 3, 2, 3, 0, 2, 0, 2, 1, 1, 0, 1, 0,
    1, 0, 3, 2, 3, 0, 0, 3, 2, 0, 1, 2, 1, 3, 0, 2, 2, 3, 3, 2, 1, 0, 3, 2,
    2, 2, 3, 0, 0, 0, 0, 0, 3, 2, 2, 1, 0, 0, 1, 1, 3, 2, 3, 3, 2, 0, 1, 1,
    0, 1, 2, 0, 2, 1, 3, 1, 0, 0, 2, 2, 2, 3, 2, 1, 2, 0, 1, 3, 2, 0, 0, 2,
    0, 0, 2, 1, 3, 2, 1, 2, 3, 3, 2, 2, 0, 3, 1, 2, 0, 2};
uint32_t current;

uint32_t f_c[4];

uint32_t compute_osr_fc(double frequency, uint8_t OSR);
void start_transmission();
void end_transmission();

uint32_t read_string(char *buf, int len) {
  uart_rx_enable();
  uart_interrupt_disable();
  uart_interrupt_clear();

  int i;
  for (i = 0; i < len - 1; i++) {
    while (!uart_interrupt_pending()) {
      // Idle
    }
    buf[i] = uart_data_read();
    uart_interrupt_clear();

    if (buf[i] == 0x0D) {
      buf[i] = '\0';
      return i;
    }
  }

  buf[i + 1] = '\0';
  return i + 1;
}

int main() {
  /* printf("Hallo!"); */
  /* while (1) { */
  /* } */
  scl_ratio_set(scl_compute_ratio(12e6, 100e3));
  *I2C_DEVICE_ADDR = 0x5A;
  *I2C_MASK = 0b0001;
  *I2C_DATA = 0x20;
  uint32_t result = *I2C_DATA;
  printf("Returned: %x\r\n", result);

  /* *I2C_MASK = 0b0010; */
  /* result = *I2C_DATA; */
  /* *I2C_DATA = result; */

  /* *I2C_MASK = 0b0011; */
  /* result = *I2C_DATA; */
  /* *I2C_DATA = result; */

  /* *I2C_MASK = 0b0101; */
  /* result = *I2C_DATA; */
  /* *I2C_DATA = result; */

  /* *I2C_MASK = 0b1111; */
  /* result = *I2C_DATA; */
  /* *I2C_DATA = result; */
  /* uint8_t result = *I2C_DATA; */
  /* printf("Returned: %x\r\n", result); */

  /* while (1) { */
  /*   uint8_t data = *GPIO_IN; */
  /*   data += 1; */
  /*   *GPIO_OUT = data; */
  /* } */

  uart_rx_set_cpb(uart_compute_cpb(CLK_FREQ, 115200));
  uart_tx_set_cpb(uart_compute_cpb(CLK_FREQ, 115200));
  interrupts_disable();
  mtvec_set_table(&mtvec_table);

  /* char buf[10]; */
  /* printf("Hallo: "); */
  /* int len = read_string(buf, 10); */
  /* printf("len: %d\r\n", len); */
  /* printf("Got: %s\r\n", buf); */
  uart_rx_enable();
  uart_interrupt_enable();
  printf("Ready\r\n");
  external_interrupt_enable();
  interrupts_enable();

  f_c[0] = compute_osr_fc(1500.0, 3);
  f_c[1] = compute_osr_fc(1501.5, 3);
  f_c[2] = compute_osr_fc(1503.0, 3);
  f_c[3] = compute_osr_fc(1504.5, 3);
  /* f_c[0] = (0b11 << 30) | 0b000000100000111010001011101110; */
  /* f_c[1] = (0b11 << 30) | 0b000001100000111010001011101110; */
  /* f_c[2] = (0b11 << 30) | 0b000001110000111010001011101110; */
  /* f_c[3] = (0b11 << 30) | 0b000010000000111010001011101110; */

  printf("Ready to transmit!\r\n");
  interrupts_enable();

  // Waiting for start button
  while (!freq_active_get()) {
  }
  printf("Started transmission.\r\n");

  // Waiting for end of transmission
  while (freq_active_get()) {
  }
  printf("Finished. Thank you for using CE CPU!\r\n");
}

void _putchar(char character) { *UART_TX = character; }

__attribute__((interrupt("machine"))) void ext_intr_handler() {
  external_interrupt_disable();
  start_transmission();
}

__attribute__((interrupt("machine"))) void timer_intr_handler() {
  current += 1;

  if (current < SYMBOL_AMOUNT) {
    printf("current: %d\r\n", current);
    mtimecmp_set(mtimecmp_get() + CYCLES_PER_SYMBOL);
    freq_osr_fc_set(f_c[symbols[current]]);
  } else {
    end_transmission();
    external_interrupt_clear();
    external_interrupt_enable();
  }
}

__attribute__((weak, interrupt("machine"))) void uart_intr_handler() {
  printf("%c", uart_data_read());
  uart_interrupt_clear();
}

void start_transmission() {
  current = 0;
  freq_reset_n_set(0);
  freq_reset_n_set(1);
  freq_start_set(0);
  freq_lo_div_set(2);
  freq_osr_fc_set(f_c[symbols[current]]);

  mtimecmp_set(CYCLES_PER_SYMBOL);
  mtime_set(0);
  freq_start_set(1);
  timer_interrupt_enable();
}

void end_transmission() {
  timer_interrupt_disable();
  freq_reset_n_set(0);
  freq_start_set(0);
}

uint32_t compute_osr_fc(double frequency, uint8_t OSR) {
  double iterations = 256.0;
  switch (OSR) {
  case 0:
    iterations = 32.0;
    break;
  case 1:
    iterations = 64.0;
    break;
  case 2:
    iterations = 128.0;
    break;
  case 3:
    iterations = 256.0;
    break;
  }

  double f_s = CLK_FREQ / iterations;
  double fc = (2.0 / f_s) * frequency;

  uint32_t osr_fc = 0;
  osr_fc |= OSR << 30;
  osr_fc |= (uint32_t)(fc * (1 << FRAQ_BITS));

  return osr_fc;
}
