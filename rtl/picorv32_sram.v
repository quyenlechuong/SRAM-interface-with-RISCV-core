module picorv32_sram #(
  parameter ADDR_WIDTH = 16,   
  parameter DATA_WIDTH = 32
) (
  input  wire                   clk,
  input  wire                   resetn,
  input  wire                   mem_valid,
  input  wire                   mem_instr,
  output wire                   mem_ready,
  output reg  [DATA_WIDTH-1:0]  mem_rdata,
  input  wire [31:0]            mem_addr,
  input  wire [DATA_WIDTH-1:0]  mem_wdata,
  input  wire [3:0]             mem_wstrb
);

  
  localparam WORD_DEPTH = (1 << (ADDR_WIDTH-2));

  (* ram_style = "block" *)
  reg [31:0] mem [0:WORD_DEPTH-1];

  // Memory initialization
  initial begin
    $readmemh("mem_init_final_2.mem", mem);
  end

  
  wire [ADDR_WIDTH-3:0] word_addr = mem_addr[ADDR_WIDTH-1:2];
  
  // Pipeline registers
  reg [ADDR_WIDTH-3:0] word_addr_d;

  reg [DATA_WIDTH-1:0] wdata_s1, wdata_s2;
  reg [3:0]            wstrb_s1, wstrb_s2;
  reg                  valid_s1, valid_s2;
  reg                  write_pending_s1, write_pending_s2;
  reg                  ram_ready;

  wire [3:0] write_enable =
      (valid_s2 && write_pending_s2) ? wstrb_s2 : 4'b0;

  //synchronous active low reset
  always @(posedge clk) begin
    if (!resetn) begin
      valid_s1 <= 0;
      valid_s2 <= 0;
      write_pending_s1 <= 0;
      write_pending_s2 <= 0;
      wdata_s1 <= 0;
      wdata_s2 <= 0;
      wstrb_s1 <= 0;
      wstrb_s2 <= 0;
      word_addr_d <= 0;
      mem_rdata <= 0;
      ram_ready <= 0;
    end else begin
      
      //addr must go through a reg before access to BRAM
      if (mem_valid && !valid_s1)
        word_addr_d <= word_addr;
        
      if (mem_valid && !valid_s1) begin
        valid_s1 <= 1'b1;
        wdata_s1 <= mem_wdata;
        wstrb_s1 <= mem_wstrb;
        write_pending_s1 <= |mem_wstrb;
      end

      
      valid_s2 <= valid_s1;
      wdata_s2 <= wdata_s1;
      wstrb_s2 <= wstrb_s1;
      write_pending_s2 <= write_pending_s1;

      //read 32 bits
      mem_rdata <= mem[word_addr_d];

      //write with write strobe
      if (write_enable[0]) mem[word_addr_d][7:0]   <= wdata_s2[7:0];
      if (write_enable[1]) mem[word_addr_d][15:8]  <= wdata_s2[15:8];
      if (write_enable[2]) mem[word_addr_d][23:16] <= wdata_s2[23:16];
      if (write_enable[3]) mem[word_addr_d][31:24] <= wdata_s2[31:24];

      
      ram_ready <= (ram_ready && !mem_valid) ? 1'b0 : valid_s2;

      if (ram_ready && !mem_valid) begin
        valid_s1 <= 0;
        valid_s2 <= 0;
        write_pending_s1 <= 0;
        write_pending_s2 <= 0;
        wstrb_s1 <= 0;
        wstrb_s2 <= 0;
      end
    end
  end

  assign mem_ready = ram_ready;

endmodule