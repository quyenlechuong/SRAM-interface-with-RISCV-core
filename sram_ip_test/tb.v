`timescale 1ns / 1ps

module tb;
 
  //signal
  reg clk;
  reg resetn;
  
  
  reg [31:0] mem_addr;
  reg [31:0] mem_wdata;
  wire [31:0] mem_rdata;
  
  reg mem_valid;
  reg mem_instr;
  wire mem_ready;
  
  reg [3:0] mem_wstrb;
  
  reg [31:0]core_rdata;
  
  //for testing
  integer i, j, z;
  
  integer err, case_of_test;
  reg [31:0] sram_output_rdata;
  reg [31:0] sram_input_wdata;
  reg [31:0] sram_addr;
  reg [3:0] strobe;
  
  //file
  integer fd;
  reg [31:0] file_word;
  integer r;
  
  //dut
  picorv32_sram dut (.clk(clk),
                     .resetn(resetn),
                     .mem_valid(mem_valid),
                     .mem_instr(mem_instr),
                     .mem_ready(mem_ready),
                     .mem_rdata(mem_rdata),
                     .mem_addr(mem_addr),
                     .mem_wdata(mem_wdata),
                     .mem_wstrb(mem_wstrb)
  );
  
  //In Top module, the output rdata of sram will go through a register or 32bit flipflop before go to the CPU
  always@(posedge clk or negedge resetn) begin
    if (!resetn) begin
        core_rdata <= 0;
    end else begin
        core_rdata <= mem_rdata;
    end
  end
  
  //CLK
  initial begin
    clk = 0;
    forever #25 clk = ~clk;
  end
  
  //RST_N
  initial begin
    resetn = 0;
    #50;
    resetn = 1;
  end
  
  //MAIN BLOCK
  initial begin
    err = 0;
    mem_addr = 0;
    mem_wdata = 0;
    mem_valid = 0;
    mem_instr = 0;
    mem_wstrb = 0;
    sram_output_rdata = 0;
    #100;
    
    
    $display("\n---------------------------------------------------------------------------");
    $display("**************************************************************************");
    $display("CASE 0: CHECK READ WITHOUT WRITE - READ INSTRUCTIONS WE HAVE STORED YET!");
    $display("**************************************************************************");
    $display("---------------------------------------------------------------------------\n");
    case_of_test = 0; //use this information to print when comapre
    
    fd = $fopen("mem_init_final_2.mem", "r");
    if (fd == 0) begin
        $display("Can not open memory file to test!");
        $finish;
    end
    
    for (i = 0; i < 29; i = i + 1) begin
        r = $fscanf(fd, "%h\n", file_word);
        if (r != 1) begin
            $display("Read file error!");
            $finish;
        end
        
        read_sram(i*4, sram_output_rdata);
        
        $display("\n----------------------------------------------------------");
        if (sram_output_rdata !== file_word) begin
            err = err + 1;
            $display("FAIL! FETCH WRONG INSTRUCTION AT ADDR: %x", i*4);
            $display("EXPECTED: %x  ACTUAL: %x", file_word, sram_output_rdata);
            $stop;
        end else begin
            $display("PASS! FETCH CORRECT INSTRUCTION AT ADDR: %x", i*4);
            $display("EXPECTED: %x  ACTUAL: %x", file_word, sram_output_rdata);
        end
        $display("----------------------------------------------------------\n");
    
    end
    
    $fclose(fd);
    
    
    
    $display("\n----------------------------------------------------------");
    $display("**********************************************************");
    $display("CASE 1: STORE WORD AND LOAD WORD TESTS!");
    $display("**********************************************************");
    $display("----------------------------------------------------------\n");
    case_of_test = 1; //use this information to print when comapre
    
    
    $display("\n-------------------------------------------------------------");
    $display("Check READ after WRITE - write same for all before read all!");
    $display("-------------------------------------------------------------\n");
    for (i = 0; i < 4; i = i + 1) begin
        if (i == 0) sram_input_wdata = 32'h0000_0000;
        else if (i == 1) sram_input_wdata = 32'hffff_ffff;
        else if (i == 2) sram_input_wdata = 32'h5555_5555;
        else sram_input_wdata = 32'haaaa_aaaa;
        $display("Write data %x to all address!", sram_input_wdata);
        for (j = 0; j < (1 << 16); j = j + 1) begin
            if (j % 4 == 0) begin
                sram_addr = j;
                write_sram(sram_addr, sram_input_wdata, 4'b1111);
            end
            
        end
        
        for (j = 0; j < (1 << 16); j = j + 1) begin
            if (j % 4 == 0) begin
                sram_addr = j;
                read_sram(sram_addr, sram_output_rdata);
                compare(sram_output_rdata, sram_input_wdata);
            end
            
        end
        
        
    end
    
    $display("\n------------------------------------------------------------------");
    $display("Check READ after WRITE - write different for all before read all!");
    $display("------------------------------------------------------------------\n");
    
    z = $random % 1000;
    
    
    //FORWARD
    for (j = 0; j < (1 << 16); j = j + 1) begin
        if (j % 4 == 0) begin
            sram_addr = j;
            sram_input_wdata = j + z;
            write_sram(sram_addr, sram_input_wdata, 4'b1111);
        end
        
    end
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
        if (j % 4 == 0) begin
            sram_addr = j;
            sram_input_wdata = j + z;
            read_sram(sram_addr, sram_output_rdata);
            compare(sram_output_rdata, sram_input_wdata);
            //What we read is the same as what we has written before!
        end
        
        
    end
    
    
    //BACKWARD
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        if (j % 4 == 0) begin
            sram_addr = j;
            sram_input_wdata = j + z;
            write_sram(sram_addr, sram_input_wdata, 4'b1111);
        end
        
    end
    
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        if (j % 4 == 0) begin
            sram_addr = j;
            sram_input_wdata = j + z;
            read_sram(sram_addr, sram_output_rdata);
            compare(sram_output_rdata, sram_input_wdata);
            //What we read is the same as what we has written before!
        end
        
        
    end
    
    
    $display("\n------------------------------------------------------------------");
    $display("CHECK READ IMMEDIATELY AFTER EACH WRITE TRANSACTION!");
    $display("------------------------------------------------------------------\n");
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
        if (j % 4 == 0) begin
            sram_addr = j;
            sram_input_wdata = j + z;
            write_sram(sram_addr, sram_input_wdata, 4'b1111);
            
            read_sram(sram_addr, sram_output_rdata); //Immediately read after a write transaction
            compare(sram_output_rdata, sram_input_wdata);
        end
        
    end
    
    
    
    
    
    
    $display("\n----------------------------------------------------------");
    $display("**********************************************************");
    $display("CASE 2: STORE BYTE AND LOAD BYTE TESTS!");
    $display("**********************************************************");
    $display("----------------------------------------------------------\n");
    case_of_test = 2;
    
    
    $display("\n-------------------------------------------------------------");
    $display("Check READ after WRITE - write same for all before read all!");
    $display("-------------------------------------------------------------\n");
    for (i = 0; i < 4; i = i + 1) begin
        if (i == 0) sram_input_wdata = 32'h0000_0000; //write byte 00
        else if (i == 1) sram_input_wdata = 32'hffff_ffff; //write byte ff
        else if (i == 2) sram_input_wdata = 32'h5555_5555; //write byte 55
        else sram_input_wdata = 32'haaaa_aaaa; //write byte aa
        $display("Write data %x to all address!", sram_input_wdata);
        for (j = 0; j < (1 << 16); j = j + 1) begin
            sram_addr = j - j % 4; //Round to the near lower word address
            if (j % 4 == 0) strobe = 4'b0001;  //strobe for masking bit
            else if (j % 4 == 1) strobe = 4'b0010;
            else if (j % 4 == 2) strobe = 4'b0100;
            else strobe = 4'b1000;
            write_sram(sram_addr, sram_input_wdata, strobe);
        end
        
        for (j = 0; j < (1 << 16); j = j + 1) begin
            
            sram_addr = j - j % 4;
            read_sram(sram_addr, sram_output_rdata);
            
            if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_00ff, sram_input_wdata & 32'h0000_00ff); //mask byte
            else if (j % 4 == 1) compare(sram_output_rdata & 32'h0000_ff00, sram_input_wdata & 32'h0000_ff00);
            else if (j % 4 == 2) compare(sram_output_rdata & 32'h00ff_0000, sram_input_wdata & 32'h00ff_0000);
            else compare(sram_output_rdata & 32'hff00_0000, sram_input_wdata & 32'hff00_0000);
            
           
            
        end
        
        
    end
    
    $display("\n------------------------------------------------------------------");
    $display("Check READ after WRITE - write different for all before read all!");
    $display("------------------------------------------------------------------\n");
    
    //FORWARD
    for (j = 0; j < (1 << 16); j = j + 1) begin
        sram_addr = j - j % 4;
        
        if (j % 4 == 0) strobe = 4'b0001;  //strobe for masking bit
        else if (j % 4 == 1) strobe = 4'b0010;
        else if (j % 4 == 2) strobe = 4'b0100;
        else strobe = 4'b1000;
        
        sram_input_wdata = {4{j[7:0]}}; //duplicate byte 4 times, byte = AB => ABABABAB
        
        write_sram(sram_addr, sram_input_wdata, strobe);
        
    end
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
        
        
        sram_input_wdata = {4{j[7:0]}}; //ANSWER TO CHECK
        sram_addr = j - j % 4;
        read_sram(sram_addr, sram_output_rdata);
        
        if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_00ff, sram_input_wdata & 32'h0000_00ff); //mask byte
        else if (j % 4 == 1) compare(sram_output_rdata & 32'h0000_ff00, sram_input_wdata & 32'h0000_ff00);
        else if (j % 4 == 2) compare(sram_output_rdata & 32'h00ff_0000, sram_input_wdata & 32'h00ff_0000);
        else compare(sram_output_rdata & 32'hff00_0000, sram_input_wdata & 32'hff00_0000);
        
        
    end
    
    
    //BACKWARD
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        sram_addr = j - j % 4;
        
        if (j % 4 == 0) strobe = 4'b0001;  //strobe for masking bit
        else if (j % 4 == 1) strobe = 4'b0010;
        else if (j % 4 == 2) strobe = 4'b0100;
        else strobe = 4'b1000;
        
        sram_input_wdata = {4{j[7:0]}}; //duplicate byte 4 times, byte = AB => ABABABAB
        
        write_sram(sram_addr, sram_input_wdata, strobe);
        
    end
    
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        
        
        sram_input_wdata = {4{j[7:0]}}; //ANSWER TO CHECK
        sram_addr = j - j % 4;
        read_sram(sram_addr, sram_output_rdata);
        
        if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_00ff, sram_input_wdata & 32'h0000_00ff); //mask byte
        else if (j % 4 == 1) compare(sram_output_rdata & 32'h0000_ff00, sram_input_wdata & 32'h0000_ff00);
        else if (j % 4 == 2) compare(sram_output_rdata & 32'h00ff_0000, sram_input_wdata & 32'h00ff_0000);
        else compare(sram_output_rdata & 32'hff00_0000, sram_input_wdata & 32'hff00_0000);
        
        
    end
    
    
    // AGAIN
    //FORWARD
    for (j = 0; j < (1 << 16); j = j + 1) begin
        sram_addr = j - j % 4;
        
        if (j % 4 == 0) strobe = 4'b0001;  //strobe for masking bit
        else if (j % 4 == 1) strobe = 4'b0010;
        else if (j % 4 == 2) strobe = 4'b0100;
        else strobe = 4'b1000;
        
        sram_input_wdata = {4{(j[7:0] % 8'hff)}}; //duplicate byte 4 times, byte = AB => ABABABAB
        
        write_sram(sram_addr, sram_input_wdata, strobe);
        
    end
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
        
        
        sram_input_wdata = {4{(j[7:0] % 8'hff)}}; //ANSWER TO CHECK
        sram_addr = j - j % 4;
        read_sram(sram_addr, sram_output_rdata);
        
        if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_00ff, sram_input_wdata & 32'h0000_00ff); //mask byte
        else if (j % 4 == 1) compare(sram_output_rdata & 32'h0000_ff00, sram_input_wdata & 32'h0000_ff00);
        else if (j % 4 == 2) compare(sram_output_rdata & 32'h00ff_0000, sram_input_wdata & 32'h00ff_0000);
        else compare(sram_output_rdata & 32'hff00_0000, sram_input_wdata & 32'hff00_0000);
        
        
    end
    
    
    //BACKWARD
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        sram_addr = j - j % 4;
        
        if (j % 4 == 0) strobe = 4'b0001;  //strobe for masking bit
        else if (j % 4 == 1) strobe = 4'b0010;
        else if (j % 4 == 2) strobe = 4'b0100;
        else strobe = 4'b1000;
        
        sram_input_wdata = {4{(j[7:0] % 8'hff)}}; //duplicate byte 4 times, byte = AB => ABABABAB
        
        write_sram(sram_addr, sram_input_wdata, strobe);
        
    end
    
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        
        
        sram_input_wdata = {4{(j[7:0] % 8'hff)}}; //ANSWER TO CHECK
        sram_addr = j - j % 4;
        read_sram(sram_addr, sram_output_rdata);
        
        if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_00ff, sram_input_wdata & 32'h0000_00ff); //mask byte
        else if (j % 4 == 1) compare(sram_output_rdata & 32'h0000_ff00, sram_input_wdata & 32'h0000_ff00);
        else if (j % 4 == 2) compare(sram_output_rdata & 32'h00ff_0000, sram_input_wdata & 32'h00ff_0000);
        else compare(sram_output_rdata & 32'hff00_0000, sram_input_wdata & 32'hff00_0000);
        
        
    end
    
    
    $display("\n------------------------------------------------------------------");
    $display("CHECK READ IMMEDIATELY AFTER EACH WRITE TRANSACTION!");
    $display("------------------------------------------------------------------\n");
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
        sram_addr = j - j % 4;
        
        if (j % 4 == 0) strobe = 4'b0001;  //strobe for masking bit
        else if (j % 4 == 1) strobe = 4'b0010;
        else if (j % 4 == 2) strobe = 4'b0100;
        else strobe = 4'b1000;
        
        sram_input_wdata = {4{(j[7:0] % 8'hff)}}; //duplicate byte 4 times, byte = AB => ABABABAB
        
        write_sram(sram_addr, sram_input_wdata, strobe);
        
        sram_input_wdata = {4{(j[7:0] % 8'hff)}}; //ANSWER TO CHECK
        sram_addr = j - j % 4;
        read_sram(sram_addr, sram_output_rdata); //Immediately Read After A WRITE TRANSACTION
        
        if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_00ff, sram_input_wdata & 32'h0000_00ff); //mask byte
        else if (j % 4 == 1) compare(sram_output_rdata & 32'h0000_ff00, sram_input_wdata & 32'h0000_ff00);
        else if (j % 4 == 2) compare(sram_output_rdata & 32'h00ff_0000, sram_input_wdata & 32'h00ff_0000);
        else compare(sram_output_rdata & 32'hff00_0000, sram_input_wdata & 32'hff00_0000);
    end
    
    
    
    
    $display("\n----------------------------------------------------------");
    $display("**********************************************************");
    $display("CASE 3: STORE HALFWORD AND LOAD HALFWORD TESTS!");
    $display("**********************************************************");
    $display("----------------------------------------------------------\n");
    case_of_test = 3;
    
    
    $display("\n-------------------------------------------------------------");
    $display("Check READ after WRITE - write same for all before read all!");
    $display("-------------------------------------------------------------\n");
    for (i = 0; i < 4; i = i + 1) begin
        if (i == 0) sram_input_wdata = 32'h0000_0000; //write hw 0000
        else if (i == 1) sram_input_wdata = 32'hffff_ffff; //write hw ffff
        else if (i == 2) sram_input_wdata = 32'h5555_5555; //write hw 5555
        else sram_input_wdata = 32'haaaa_aaaa; //write hw aaaa
        $display("Write data %x to all address!", sram_input_wdata);
        for (j = 0; j < (1 << 16); j = j + 1) begin
            if (j % 2 == 0) begin
                sram_addr = j - j % 4; //Round to the near lower word address
                if (j % 4 == 0) strobe = 4'b0011;  //strobe for masking bit
                else strobe = 4'b1100;
                write_sram(sram_addr, sram_input_wdata, strobe);
            
            end
            
        end
        
        for (j = 0; j < (1 << 16); j = j + 1) begin
            
            if (j % 2 == 0) begin
                sram_addr = j - j % 4;
                read_sram(sram_addr, sram_output_rdata);
                
                if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_ffff, sram_input_wdata & 32'h0000_ffff); //mask byte
                else compare(sram_output_rdata & 32'hffff_0000, sram_input_wdata & 32'hffff_0000);
            end   
        end
        
        
    end
    
    $display("\n------------------------------------------------------------------");
    $display("Check READ after WRITE - write different for all before read all!");
    $display("------------------------------------------------------------------\n");
    
    //FORWARD
    for (j = 0; j < (1 << 16); j = j + 1) begin
    
        if (j % 2 == 0) begin
            sram_addr = j - j % 4;
            
            if (j % 4 == 0) strobe = 4'b0011;  //strobe for masking bit
            else strobe = 4'b1100;
            
            sram_input_wdata = {2{j[15:0]}}; //duplicate byte 4 times, byte = AB => ABABABAB
            
            write_sram(sram_addr, sram_input_wdata, strobe);
        end
        
        
    end
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
        
        if (j % 2 == 0) begin
            sram_input_wdata = {2{j[15:0]}}; //ANSWER TO CHECK
            sram_addr = j - j % 4;
            read_sram(sram_addr, sram_output_rdata);
            
            if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_ffff, sram_input_wdata & 32'h0000_ffff); //mask byte
            else compare(sram_output_rdata & 32'hffff_0000, sram_input_wdata & 32'hffff_0000);
        end
        
        
        
    end
    
    
    //BACKWARD
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        if (j % 2 == 0) begin
            sram_addr = j - j % 4;
            
            if (j % 4 == 0) strobe = 4'b0011;  //strobe for masking bit
            else strobe = 4'b1100;
            
            sram_input_wdata = {2{j[15:0]}}; //duplicate byte 4 times, byte = AB => ABABABAB
            
            write_sram(sram_addr, sram_input_wdata, strobe);
        end
        
    end
    
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        
        
        if (j % 2 == 0) begin
            sram_input_wdata = {2{j[15:0]}}; //ANSWER TO CHECK
            sram_addr = j - j % 4;
            read_sram(sram_addr, sram_output_rdata);
            
            if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_ffff, sram_input_wdata & 32'h0000_ffff); //mask byte
            else compare(sram_output_rdata & 32'hffff_0000, sram_input_wdata & 32'hffff_0000);
        end
        
        
    end
    
    
    // AGAIN
    //FORWARD
    for (j = 0; j < (1 << 16); j = j + 1) begin
    
        if (j % 2 == 0) begin
            sram_addr = j - j % 4;
            
            if (j % 4 == 0) strobe = 4'b0011;  //strobe for masking bit
            else strobe = 4'b1100;
            
            sram_input_wdata = {2{(j[15:0] % 16'hffff)}}; //duplicate byte 4 times, byte = AB => ABABABAB
            
            write_sram(sram_addr, sram_input_wdata, strobe);
        end
        
        
    end
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
        
        if (j % 2 == 0) begin
            sram_input_wdata = {2{(j[15:0] % 16'hffff)}}; //ANSWER TO CHECK
            sram_addr = j - j % 4;
            read_sram(sram_addr, sram_output_rdata);
            
            if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_ffff, sram_input_wdata & 32'h0000_ffff); //mask byte
            else compare(sram_output_rdata & 32'hffff_0000, sram_input_wdata & 32'hffff_0000);
        end
        
        
        
    end
    
    
    //BACKWARD
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        if (j % 2 == 0) begin
            sram_addr = j - j % 4;
            
            if (j % 4 == 0) strobe = 4'b0011;  //strobe for masking bit
            else strobe = 4'b1100;
            
            sram_input_wdata = {2{(j[15:0] % 16'hffff)}}; //duplicate byte 4 times, byte = AB => ABABABAB
            
            write_sram(sram_addr, sram_input_wdata, strobe);
        end
        
    end
    
    for (j = (1 << 16) - 1; j >= 0 ; j = j - 1) begin
        
        
        if (j % 2 == 0) begin
            sram_input_wdata = {2{(j[15:0] % 16'hffff)}}; //ANSWER TO CHECK
            sram_addr = j - j % 4;
            read_sram(sram_addr, sram_output_rdata);
            
            if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_ffff, sram_input_wdata & 32'h0000_ffff); //mask byte
            else compare(sram_output_rdata & 32'hffff_0000, sram_input_wdata & 32'hffff_0000);
        end
        
        
    end
    
    $display("\n------------------------------------------------------------------");
    $display("CHECK READ IMMEDIATELY AFTER EACH WRITE TRANSACTION!");
    $display("------------------------------------------------------------------\n");
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
    
        if (j % 2 == 0) begin
            sram_addr = j - j % 4;
            
            if (j % 4 == 0) strobe = 4'b0011;  //strobe for masking bit
            else strobe = 4'b1100;
            
            sram_input_wdata = {2{(j[15:0] % 16'hffff)}}; //duplicate byte 4 times, byte = AB => ABABABAB
            
            write_sram(sram_addr, sram_input_wdata, strobe);
            
            
            sram_input_wdata = {2{(j[15:0] % 16'hffff)}}; //ANSWER TO CHECK
            sram_addr = j - j % 4;
            read_sram(sram_addr, sram_output_rdata);
            
            if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_ffff, sram_input_wdata & 32'h0000_ffff); //mask byte
            else compare(sram_output_rdata & 32'hffff_0000, sram_input_wdata & 32'hffff_0000);
        end  
    end
    
    
    
    
    // LITTLE ENDIAN
    $display("\n----------------------------------------------------------");
    $display("**********************************************************");
    $display("CASE 4: LITTLE ENDIAN TESTS!");
    $display("**********************************************************");
    $display("----------------------------------------------------------\n");
    case_of_test = 4;
    
    //STOTRE WORD THEN LOAD BYTE TO CHECK
    $display("\n--------------------------------------------------------------------");
    $display("STORE WORD AND THEN LOAD 4 CONTIGUOUS BYTES OF THAT WORD TO CHECK");
    $display("--------------------------------------------------------------------\n");
    
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
        if (j % 4 == 0) begin
            sram_addr = j;
            write_sram(sram_addr, 32'hABCD_1234, 4'b1111);
        end
        
    end
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
            
        sram_addr = j - j % 4;
        read_sram(sram_addr, sram_output_rdata);
        
        if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_00ff, 32'hABCD_1234 & 32'h0000_00ff); //mask byte
        else if (j % 4 == 1) compare(sram_output_rdata & 32'h0000_ff00, 32'hABCD_1234 & 32'h0000_ff00);
        else if (j % 4 == 2) compare(sram_output_rdata & 32'h00ff_0000, 32'hABCD_1234 & 32'h00ff_0000);
        else compare(sram_output_rdata & 32'hff00_0000, 32'hABCD_1234 & 32'hff00_0000);    
    end
    
    //STORE HALFWORD AND LOAD BYTE TO CHECK
    $display("\n-------------------------------------------------------------------------");
    $display("STORE HALFWORD AND THEN LOAD 2 CONTIGUOUS BYTES OF THAT HALFWORD TO CHECK");
    $display("-------------------------------------------------------------------------\n");
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
        if (j % 2 == 0) begin
            sram_addr = j - j % 4; //Round to the near lower word address
            if (j % 4 == 0) strobe = 4'b0011;  //strobe for masking bit
            else strobe = 4'b1100;
            write_sram(sram_addr, 32'h5678_90EF, strobe);
        
        end
        
    end
    
    
    for (j = 0; j < (1 << 16); j = j + 1) begin
            
        sram_addr = j - j % 4;
        read_sram(sram_addr, sram_output_rdata);
        
        if (j % 4 == 0) compare(sram_output_rdata & 32'h0000_00ff, 32'h5678_90EF & 32'h0000_00ff); //mask byte
        else if (j % 4 == 1) compare(sram_output_rdata & 32'h0000_ff00, 32'h5678_90EF & 32'h0000_ff00);
        else if (j % 4 == 2) compare(sram_output_rdata & 32'h00ff_0000, 32'h5678_90EF & 32'h00ff_0000);
        else compare(sram_output_rdata & 32'hff00_0000, 32'h5678_90EF & 32'hff00_0000);    
    end
    
    
    if (err == 0) $display("PASSED ALL TESTS!");
    else $display("FAILED SOME TESTS!");
    
    #100;
    $display("END!");
    $finish;
  end
  
  
  task write_sram;
    input [31:0] addr;
    input [31:0] wdata;
    input [31:0] wstrb; // for store byte, store halfword and store word
    begin
        //assign addr and wdata
        mem_addr = addr;
        mem_wdata = wdata;
        
        $display("t=%10d [WRITE_SRAM]: addr=%x data=%x wstrb=%4b", $time, mem_addr, mem_wdata, wstrb);
        @(posedge clk); //request sram
        #1;
        mem_valid = 1;
        mem_wstrb = wstrb; //We use sram to write 1 word
        #1;
        wait(mem_ready); //wait sram reply
        #1;
        @(posedge clk);
        #1;
        mem_valid = 0;
        mem_wstrb = 4'b0; //stop request sram
        
    end
  endtask
  
  
  task read_sram;
    input [31:0] addr;
    output [31:0] rdata;
    begin
        //assign addr
        mem_addr = addr;
        @(posedge clk); //request sram
        #1;
        mem_valid = 1;
        mem_wstrb = 4'b0;
        #1;
        wait(mem_ready); //wait sram reply
        #1; rdata = core_rdata;
        
        @(posedge clk);
        #1;
        mem_valid = 0;
        mem_wstrb = 4'b0; //stop request sram
        $display("t=%10d [READ_SRAM]: addr=%x rdata=%x", $time, addr, rdata);
    end
  endtask
  
  task compare;
      input [31:0] output_data;
      input [31:0] expected_data;
      
      
      if (output_data !== expected_data) begin
        err = err + 1;
            $display("\n---------------------------------------------------");
            $display("THIS TEST IN CASE %0d", case_of_test);
        if (case_of_test == 1) begin
            
            $display("t=%10d FAIL: CPU CHECK LOAD WORD IS NOT CORRECT", $time);
            $display("Expected: %x Actual: %x",expected_data, output_data);
            
        end else if (case_of_test == 2  || case_of_test == 4) begin
            $display("t=%10d FAIL: CPU CHECK LOAD BYTE IS NOT CORRECT", $time);
            if (j % 4 == 0) $display("Expected: %02x Actual: %02x",expected_data[7:0], output_data[7:0]);
            else if (j % 4 == 1) $display("Expected: %02x Actual: %02x",expected_data[15:8], output_data[15:8]);
            else if (j % 4 == 2) $display("Expected: %02x Actual: %02x",expected_data[23:16], output_data[23:16]);
            else $display("Expected: %02x Actual: %02x",expected_data[31:24], output_data[31:24]);
            
        end else begin
            $display("t=%10d FAIL: CPU CHECK LOAD HALFWORD IS NOT CORRECT", $time);
            if (j % 4 == 0) $display("Expected: %04x Actual: %04x",expected_data[15:0], output_data[15:0]);
            else $display("Expected: %04x Actual: %04x",expected_data[31:16], output_data[31:16]);
        end
            $display("---------------------------------------------------\n");
            $stop;
        
      end else begin
      
      $display("\n---------------------------------------------------");
      $display("THIS TEST IN CASE %0d", case_of_test);
        if (case_of_test == 1) begin
            
            $display("t=%10d PASS: CPU CHECK LOAD WORD IS CORRECT", $time);
            $display("Expected: %x Actual: %x",expected_data, output_data);
            
        end else if (case_of_test == 2 || case_of_test == 4) begin
            $display("t=%10d PASS: CPU CHECK LOAD BYTE IS CORRECT", $time);
            if (j % 4 == 0) $display("Expected: %02x Actual: %02x",expected_data[7:0], output_data[7:0]);
            else if (j % 4 == 1) $display("Expected: %02x Actual: %02x",expected_data[15:8], output_data[15:8]);
            else if (j % 4 == 2) $display("Expected: %02x Actual: %02x",expected_data[23:16], output_data[23:16]);
            else $display("Expected: %02x Actual: %02x",expected_data[31:24], output_data[31:24]);
            
        end else begin
            $display("t=%10d PASS: CPU CHECK LOAD HALFWORD IS CORRECT", $time);
            if (j % 4 == 0) $display("Expected: %04x Actual: %04x",expected_data[15:0], output_data[15:0]);
            else $display("Expected: %04x Actual: %04x",expected_data[31:16], output_data[31:16]);
        end
            $display("---------------------------------------------------\n");
      end
  
  endtask
  
endmodule
