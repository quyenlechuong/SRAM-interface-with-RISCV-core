module uart_rx #(
    parameter integer CLK_FREQ = 125_000_000,
    parameter integer BAUD     = 115200
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire        rx,        

    output wire [7:0]  rx_data,   
    output wire        rx_ready,  // =1 when at leaste 1 byte in buffer, delayed 1 clk
    input  wire        rx_ack     
);

    
    localparam integer BAUD_CNT = CLK_FREQ / BAUD;

    
    localparam integer FIRST_CNT = BAUD_CNT + (BAUD_CNT >> 1) - 1; 
    localparam integer PERIOD_CNT = BAUD_CNT - 1;                  

    // regs
    reg [15:0] baud_cnt;
    reg [3:0]  bit_idx;
    reg [7:0]  shift_reg;
    reg        receiving;

    // double buffer
    reg [7:0] buf0, buf1;
    reg       buf0_valid, buf1_valid;

    // rx sync and edge detect
    reg rx_sync0, rx_sync1;
    wire start_edge;

    // rx_ready delayed 1 clk
    reg rx_ready_r;
    assign rx_ready = rx_ready_r;
    assign rx_data  = buf0;

    // Edge detect on synchronized signal: previous high -> now low
    assign start_edge = (rx_sync1 == 1'b1) && (rx_sync0 == 1'b0);

    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rx_sync0    <= 1'b1;
            rx_sync1    <= 1'b1;
            baud_cnt    <= 0;
            bit_idx     <= 0;
            shift_reg   <= 0;
            receiving   <= 1'b0;

            buf0        <= 0;
            buf1        <= 0;
            buf0_valid  <= 1'b0;
            buf1_valid  <= 1'b0;

            rx_ready_r  <= 1'b0;
        end else begin
            // synchronize rx
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;

            // CPU has read 1 byte → dịch buffer
            if (rx_ack && buf0_valid) begin
                if (buf1_valid) begin
                    buf0       <= buf1;
                    buf1_valid <= 1'b0;
                    buf0_valid <= 1'b1;
                end else begin
                    buf0_valid <= 1'b0;
                end
            end

            // UART receiving state machine
            if (!receiving) begin
                // wait start bit: detect falling edge on synchronized line
                if (start_edge) begin
                    receiving <= 1'b1;
                    baud_cnt  <= FIRST_CNT;  
                    bit_idx   <= 0;
                end
            end else begin
                if (baud_cnt != 0) begin
                    baud_cnt <= baud_cnt - 16'd1;
                end else begin
                    // sample time
                    // After sampling, set counter for next bit: BAUD_CNT - 1 (count to 0)
                    baud_cnt <= PERIOD_CNT;

                    if (bit_idx < 8) begin
                        shift_reg[bit_idx] <= rx_sync0; // sample synchronized rx
                        bit_idx <= bit_idx + 1;
                    end else begin
                        // stop bit sampled (we are at stop)
                        receiving <= 1'b0;

                        // WRITE TO DOUBLE BUFFER
                        if (!buf0_valid) begin
                            buf0       <= shift_reg;
                            buf0_valid <= 1'b1;
                        end else if (!buf1_valid) begin
                            buf1       <= shift_reg;
                            buf1_valid <= 1'b1;
                        end else begin
                            // overflow -> skip
                        end
                    end
                end
            end

            // Delay 1 cycle for rx_ready
            rx_ready_r <= buf0_valid;
        end
    end
endmodule