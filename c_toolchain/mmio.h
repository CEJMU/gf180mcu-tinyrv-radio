#ifndef MMIO_H_
#define MMIO_H_

#include <stdint.h>

extern volatile char *const GPIO_OUT;
extern volatile char *const GPIO_IN;

extern volatile char *const UART_TX;

extern volatile char *const I2C_DEVICE_ADDR;
extern volatile int *const I2C_DATA;
extern volatile char *const I2C_MASK;

extern volatile unsigned int *const MTIME;
extern volatile unsigned int *const MTIMEH;
extern volatile unsigned int *const MTIMECMP;
extern volatile unsigned int *const MTIMECMPH;

extern volatile uint8_t *const FREQ_STATUS;
extern volatile uint32_t *const FREQ_OSR_FC;
extern volatile uint8_t *const FREQ_LO_DIV;

void freq_reset_n_set(uint8_t reset_n);
void freq_start_set(uint8_t start);
uint8_t freq_active_get();
uint32_t freq_osr_fc_get();
void freq_osr_fc_set(uint32_t osr_fc);
void freq_lo_div_set(uint8_t lo_div);

#endif // MMIO_H_
