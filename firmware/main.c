#define LED_ADDR       0x10000000u
#define UART_TX_ADDR   0x10000004u
#define UART_RX_ADDR   0x10000008u   // read → blocks until byte is ready

#define IMAGE_BASE     0x00010000u
#define IMAGE_SIZE     98304u

static inline void mmio_write(unsigned int addr, unsigned int val) {
    *(volatile unsigned int *)addr = val;
}

static inline unsigned int mmio_read(unsigned int addr) {
    return *(volatile unsigned int *)addr;
}

/* UART TX: write 1 byte */
static inline void uart_putc(unsigned char c) {
    *(volatile unsigned int *)UART_TX_ADDR = c;
}

/* UART RX: relies on hardware mem_ready blocking until byte available */
static inline unsigned char uart_getc(void) {
    return (unsigned char)(mmio_read(UART_RX_ADDR) & 0xFFu);
}

/* store byte to SRAM (BYTE write) */
static inline void store_byte(unsigned int addr, unsigned char b) {
    *(volatile unsigned char *)addr = b;
}

int main(void) {
    unsigned int i;
    unsigned char b;

    // Indicate start receiving
    mmio_write(LED_ADDR, 0x55);

    // Receive IMAGE_SIZE bytes into SRAM
    for (i = 0; i < IMAGE_SIZE; i++) {
        b = uart_getc();                // CPU waits until byte ready
        store_byte(IMAGE_BASE + i, b);  // store to SRAM
    }

    // Indicate receive done
    mmio_write(LED_ADDR, 0xCC);

    // Resend the stored image back through UART
    for (i = 0; i < IMAGE_SIZE; i++) {
        unsigned char outb = *(volatile unsigned char *)(IMAGE_BASE + i);
        uart_putc(outb);
    }

    // Final done
    mmio_write(LED_ADDR, 0xAA);

    while (1) {
    }
    return 0;
}

