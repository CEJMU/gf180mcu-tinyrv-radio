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
volatile uint8_t *const FREQ_DS_LO_CONF = (uint8_t *)(GPIO_OUT + 32);

volatile uint8_t *const UART_RX_STATUS = (uint8_t *)(GPIO_OUT + 33);
volatile uint8_t *const UART_RX_DATA = (uint8_t *)(GPIO_OUT + 34);

volatile uint16_t *const UART_RX_CPB = (uint16_t *)(GPIO_OUT + 36);
volatile uint16_t *const UART_TX_CPB = (uint16_t *)(GPIO_OUT + 40);
volatile uint16_t *const SCL_RATIO = (uint16_t *)(GPIO_OUT + 44);

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

void freq_lo_div_set(uint8_t lo_div) {
  uint8_t tmp = *FREQ_DS_LO_CONF;
  tmp = tmp & 0b11111000;       // Set [2:0] to 0
  lo_div = lo_div & 0b00000111; // Set everything except [2:0] to zero
  tmp = tmp | lo_div;           // Combine

  *FREQ_DS_LO_CONF = tmp;
}

void freq_ds_mode_set(uint8_t mode) {
  uint8_t tmp = *FREQ_DS_LO_CONF;
  tmp = tmp & 0b11110111;
  mode = mode & 0b00000001;
  mode = mode << 3;
  tmp = tmp | mode;

  *FREQ_DS_LO_CONF = tmp;
}

void freq_ds_out_invert_set(uint8_t out_invert) {
  uint8_t tmp = *FREQ_DS_LO_CONF;
  tmp = tmp & 0b11101111;
  out_invert = out_invert & 0b00000001;
  out_invert = out_invert << 4;
  tmp = tmp | out_invert;

  *FREQ_DS_LO_CONF = tmp;
}

char uart_data_read() { return *UART_RX_DATA; }

uint8_t uart_data_valid() {
  uint8_t current_status = *UART_RX_STATUS;
  return current_status & 0x04;
}

void uart_rx_enable() {
  uint8_t current_status = *UART_RX_STATUS;
  current_status |= 0x01;
  *UART_RX_STATUS = current_status;
}

void uart_rx_disable() {
  uint8_t current_status = *UART_RX_STATUS;
  current_status &= 0xFE;
  *UART_RX_STATUS = current_status;
}

uint16_t uart_compute_cpb(uint32_t freq_ns, uint32_t baud) {
  double bit_p = 1e9 * (1.0 / baud);
  double clk_p = 1e9 * (1.0 / freq_ns);
  return (uint16_t)(bit_p / clk_p);
}

void uart_rx_set_cpb(uint16_t cpb) { *UART_RX_CPB = cpb; }

void uart_tx_set_cpb(uint16_t cpb) { *UART_TX_CPB = cpb; }

uint16_t scl_compute_ratio(uint32_t freq_ns, uint32_t scl_ns) {
  double ratio = (double)freq_ns / scl_ns;
  ratio = ratio / 2;
  return (uint16_t)ratio;
}

void scl_ratio_set(uint16_t scl_ratio) { *SCL_RATIO = scl_ratio; }
