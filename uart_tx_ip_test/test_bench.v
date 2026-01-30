`timescale 1ns / 1ps


//uart 1 start bit, 1 stop bit, none parity, 8 bit data
module test_bench;
    
  parameter REV_CLK_FREQ = 1_120_000_000;
  parameter BAUD_RATE    = 115200;
  parameter BAUD_CNT = REV_CLK_FREQ/BAUD_RATE;
  //signal
  reg       clk;
  reg       resetn;
  reg       tx_start;     // pulse 1 clock cycle
  reg [7:0] tx_data;
  wire      tx;
  wire      busy;
  
  //for testing
  reg       resetn_test;
  reg       tx_start_test;
  reg       frame_test_finish;
  reg [9:0] output_frame;
  
  integer   reset_err;
  integer   valid_err;
  integer   frame_err;
  
  //receiver signal
  reg       rev_clk;
  
  uart_tx dut (
    .clk(clk),
    .resetn(resetn),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx(tx),
    .busy(busy)
  );

initial begin

end

// 1120 / 125 = 224 / 25

//rev_clk is 1120 MHZ (1.12 GHZ)
//In this test bench, for simple, we assume that receiver clock rate is constant
initial begin
    rev_clk = 0;
    forever #25 rev_clk = ~rev_clk;
end

//clk for uart_tx is 125 MHZ
initial begin
    clk = 0;
    forever # 224 clk = ~clk;
end

initial begin
    resetn = 0;
    tx_start = 0;
    tx_data = 0;
    resetn_test = 0;
    tx_start_test = 0;
    frame_test_finish = 0;
    reset_err = 0;
    valid_err = 0;
    frame_err = 0;
    
    
    #1000;
    $display("Case 1: Check when resetn is active low");
    resetn_test = 1;
    #10;
    
    repeat(10) begin
        @(posedge clk);
        #1 tx_start = 1;
        tx_data = $random();
        @(posedge clk);
        #1 tx_start = 0;
        tx_data = 0;
        #2000;
    end
    
    resetn_test = 0;
    if (reset_err == 1) begin
        $display("FAIL CASE 1: TX is 0 when resetn is 0");
        $display("EXPECTED: TX is always 1 when resetn is 0");
    end else begin
        $display("PASS CASE 1");
    end
    
    resetn = 1;
    $display("Case 2: Check when tx_start signal is 0 and no byte transfer occuring");
    tx_start = 0;
    tx_start_test = 1;
    #10
    repeat(10) begin
        @(posedge clk);
        #1 tx_data = $random();
        @(posedge clk);
        #1 tx_data = 0;
        #2000;
    end
    tx_start_test = 0;
    
    if (valid_err == 1) begin
        $display("FAIL CASE 2: TX is 0 when tx_start = 0");
        $display("EXPECTED: TX is always 1 when (tx_start = 0 and no byte transfer occuring)");
    end else begin
        $display("PASS CASE 2");
    end
    
    $display("Case 3: Check data transfer");
    
    repeat(256*10) begin
        @(posedge clk);
        
        output_frame = 0;
        #1 tx_data = $random() % 256;
        tx_start = 1;
        frame_test_finish = 0;
        @(posedge clk);
        #1 tx_start = 0;
        wait (frame_test_finish);
        #1;
        
        if(output_frame !== {1'b1, tx_data, 1'b0}) begin
            frame_err = frame_err + 1;
            $display("FAIL: FRAME IS NOT CORRECT");
            $display("EXPECTED: %b, ACTUAL: %b", {1'b1, tx_data, 1'b0}, output_frame);
            $stop;
        end else begin
            $display("PASS: FRAME IS CORRECT %b", output_frame);
        end
    end
    
    if (reset_err + valid_err + frame_err > 0) begin
        $display("FAIL SOME TESTS!");
    end else begin
        $display("PASS ALL TESTS!");
    end
    
    
    
    # 100;
    $finish;
end

integer i;
always @(posedge rev_clk) begin
    if (tx == 0) begin
        #((BAUD_CNT/2) * 50); //50 is REV_CLK_CYCLE
        if (tx == 0) begin
            //sample at center of bit
            output_frame[0] = 1'b0;
            for (i = 1; i < 10; i = i + 1) begin
                #(BAUD_CNT * 50);
                #1; output_frame[i] = tx;
                if (i == 9)
                    frame_test_finish = 1;
            end  
        end
        //if TX not still 1 after baud_cnt/2 clock -> just skip
    end
end

always @(*) begin
    if (resetn_test) begin
        #1;
        $display("CHECK TX IS 1 OR NOT!");
        while(resetn_test) begin
            if (tx !== 1) begin 
                reset_err = 1;
            end
            #10;
        end
    
    end
end

always @(*) begin
    if (tx_start_test) begin
        #1;
        $display("CHECK TX IS 1 OR NOT!");
        while(tx_start_test) begin
            if (tx !== 1) begin 
                valid_err = 1;
            end
            #10;
        end
    
    end
end

endmodule