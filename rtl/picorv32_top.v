module picorv32_top (
    input  wire clk,          // board clock (125 MHz)
    input  wire resetn_in,    // active-low reset
    output wire uart_tx_pin,  // UART TX output pin
    input  wire uart_rx_pin,  // UART RX input pin
    output wire [7:0] leds    // LEDs output
);

    
    localparam SRAM_ADDR_W = 16;        
    localparam CLK_FREQ    = 125_000_000;
    localparam BAUD        = 115200;

    //connect between cpu core and top module
    wire        core_mem_valid;
    wire        core_mem_instr;
    wire [31:0] core_mem_addr;
    wire [31:0] core_mem_wdata;
    wire [3:0]  core_mem_wstrb;
    wire [31:0] core_mem_rdata;
    wire        core_mem_ready_in;

    //SRAM signals
    wire        sram_mem_valid;
    wire        sram_mem_instr;
    wire        sram_mem_ready;
    wire [31:0] sram_mem_rdata;

    
    // 0x1000_0000 : LED
    // 0x1000_0004 : UART TX
    // 0x1000_0008 : UART RX
    wire mmio_led_sel     = (core_mem_addr[31:4] == 28'h1000000) && (core_mem_addr[3:0] == 4'h0);
    wire mmio_uart_tx_sel = (core_mem_addr[31:4] == 28'h1000000) && (core_mem_addr[3:0] == 4'h4);
    wire mmio_uart_rx_sel = (core_mem_addr[31:4] == 28'h1000000) && (core_mem_addr[3:0] == 4'h8);

    // forward non-MMIO traffic to SRAM
    assign sram_mem_valid = core_mem_valid & ~(mmio_led_sel | mmio_uart_tx_sel | mmio_uart_rx_sel);
    assign sram_mem_instr = core_mem_instr;

    //SRAM
    picorv32_sram #(
        .ADDR_WIDTH(SRAM_ADDR_W),
        .DATA_WIDTH(32)
    ) u_sram (
        .clk        (clk),
        .resetn     (resetn_in),
        .mem_valid  (sram_mem_valid),
        .mem_instr  (sram_mem_instr),
        .mem_ready  (sram_mem_ready),
        .mem_rdata  (sram_mem_rdata),
        .mem_addr   (core_mem_addr),
        .mem_wdata  (core_mem_wdata),
        .mem_wstrb  (core_mem_wstrb)
    );

    
    // TX
    reg        uart_tx_start;
    reg [7:0]  uart_tx_byte;
    wire       uart_busy;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) u_uart_tx (
        .clk      (clk),
        .resetn   (resetn_in),
        .tx_start (uart_tx_start),
        .tx_data  (uart_tx_byte),
        .tx       (uart_tx_pin),
        .busy     (uart_busy)
    );

    // RX
    wire [7:0] uart_rx_byte;
    wire       uart_rx_ready;
    reg        uart_rx_ack;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) u_uart_rx (
        .clk      (clk),
        .resetn   (resetn_in),
        .rx       (uart_rx_pin),
        .rx_data  (uart_rx_byte),
        .rx_ready (uart_rx_ready),
        .rx_ack   (uart_rx_ack)
    );

    
    reg [7:0] led_reg;
    assign leds = led_reg;

    
    reg        mmio_ready_reg;
    reg [31:0] core_rdata_reg;

    assign core_mem_rdata    = core_rdata_reg;
    assign core_mem_ready_in = sram_mem_ready | mmio_ready_reg;

    // ======================================
    //      INSTANTIATE PICORV32
    // ======================================
    wire        mem_la_read_w, mem_la_write_w;
    wire [31:0] mem_la_addr_w, mem_la_wdata_w;
    wire [3:0]  mem_la_wstrb_w;

    wire        pcpi_valid_w;
    wire [31:0] pcpi_insn_w, pcpi_rs1_w, pcpi_rs2_w, pcpi_rd_w;
    wire [31:0] eoi_w;
    wire        trap_w;

    wire        trace_valid_w;
    wire [35:0] trace_data_w;

    picorv32 u_pico (
        .clk            (clk),
        .resetn         (resetn_in),
        .trap           (trap_w),

        .mem_valid      (core_mem_valid),
        .mem_instr      (core_mem_instr),
        .mem_ready      (core_mem_ready_in),

        .mem_addr       (core_mem_addr),
        .mem_wdata      (core_mem_wdata),
        .mem_wstrb      (core_mem_wstrb),
        .mem_rdata      (core_mem_rdata),

        .mem_la_read    (mem_la_read_w),
        .mem_la_write   (mem_la_write_w),
        .mem_la_addr    (mem_la_addr_w),
        .mem_la_wdata   (mem_la_wdata_w),
        .mem_la_wstrb   (mem_la_wstrb_w),

        .pcpi_valid     (pcpi_valid_w),
        .pcpi_insn      (pcpi_insn_w),
        .pcpi_rs1       (pcpi_rs1_w),
        .pcpi_rs2       (pcpi_rs2_w),
        .pcpi_wr        (1'b0),
        .pcpi_rd        (pcpi_rd_w),
        .pcpi_wait      (1'b0),
        .pcpi_ready     (1'b0),

        .irq            (32'b0),
        .eoi            (eoi_w),

        .trace_valid    (trace_valid_w),
        .trace_data     (trace_data_w)
    );

    always @(posedge clk) begin
        if (!resetn_in) begin
            mmio_ready_reg <= 1'b0;
            core_rdata_reg <= 32'b0;
            uart_tx_start  <= 1'b0;
            uart_tx_byte   <= 8'b0;
            led_reg        <= 8'b0;
            uart_rx_ack    <= 1'b0;
        end else begin
            
            mmio_ready_reg <= 1'b0;
            uart_tx_start  <= 1'b0;
            uart_rx_ack    <= 1'b0;

            //MMIO access
            if (core_mem_valid && (mmio_led_sel || mmio_uart_tx_sel || mmio_uart_rx_sel)) begin

                // ---------- WRITE ----------
                if (core_mem_wstrb != 4'b0000) begin

                    // LED WRITE
                    if (mmio_led_sel) begin
                        led_reg        <= core_mem_wdata[7:0];
                        mmio_ready_reg <= 1'b1;      // ACK immediately
                    end

                    // UART TX WRITE
                    if (mmio_uart_tx_sel) begin
                        if (!uart_busy) begin
                            uart_tx_byte   <= core_mem_wdata[7:0];
                            uart_tx_start  <= 1'b1;
                            mmio_ready_reg <= 1'b1;  
                        end else begin
                            mmio_ready_reg <= 1'b0;  // CPU STALL
                        end
                    end

                    // UART RX WRITE 
                    if (mmio_uart_rx_sel) begin
                        uart_rx_ack    <= 1'b1;
                        mmio_ready_reg <= 1'b1;
                    end

                end else begin
                    // ---------- READ MMIO ----------
                    if (mmio_uart_rx_sel) begin
                        
                        if (uart_rx_ready) begin
                            core_rdata_reg <= {24'b0, uart_rx_byte};
                            mmio_ready_reg <= 1'b1;   
                            uart_rx_ack    <= 1'b1;   
                        end else begin
                            mmio_ready_reg <= 1'b0;  
                        end
                    end else begin
                        mmio_ready_reg <= 1'b1;
                        if (mmio_led_sel)
                            core_rdata_reg <= {24'b0, led_reg};
                        else if (mmio_uart_tx_sel)
                            core_rdata_reg <= {31'b0, uart_busy};
                        else
                            core_rdata_reg <= 32'b0;
                    end
                end

            end else begin
                //SRAM READ
                core_rdata_reg <= sram_mem_rdata;
            end
        end
    end

endmodule