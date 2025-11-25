#include "mmio.h"

volatile char *const GPIO_OUT = (char *)0x0800000;
volatile char *const GPIO_IN = (char *)(GPIO_OUT + 1);

volatile char *const UART_TX = (char *)(GPIO_OUT + 2);

volatile char *const I2C_DEVICE_ADDR = (char *)(GPIO_OUT + 3);
volatile int *const I2C_DATA = (int *)(GPIO_OUT + 4);
volatile char *const I2C_MASK = (char *)(GPIO_OUT + 5);

volatile unsigned int *const MTIME = (unsigned int *)(GPIO_OUT + 8);
volatile unsigned int *const MTIMEH = (unsigned int *)(GPIO_OUT + 12);
volatile unsigned int *const MTIMECMP = (unsigned int *)(GPIO_OUT + 16);
volatile unsigned int *const MTIMECMPH = (unsigned int *)(GPIO_OUT + 20);

volatile uint8_t *const FREQ_STATUS = (uint8_t *)(GPIO_OUT + 24);
volatile uint32_t *const FREQ_OSR_FC = (uint32_t *)(GPIO_OUT + 28);
volatile uint8_t *const FREQ_LO_DIV = (uint8_t *)(GPIO_OUT + 32);

void freq_reset_n_set(uint8_t reset_n) {
  uint8_t status = *FREQ_STATUS;
  status &= 0xFE;
  status |= reset_n;
  *FREQ_STATUS = status;
}

void freq_start_set(uint8_t start) {
  uint8_t status = *FREQ_STATUS;
  status &= 0xFD;
  status |= (start << 1);
  *FREQ_STATUS = status;
}

uint8_t freq_active_get() {
  uint8_t status = *FREQ_STATUS;
  status &= 0xFB;
  return status;
}

uint32_t freq_osr_fc_get() { return *FREQ_OSR_FC; }

void freq_osr_fc_set(uint32_t osr_fc) { *FREQ_OSR_FC = osr_fc; }

void freq_lo_div_set(uint8_t lo_div) { *FREQ_LO_DIV = lo_div; }
