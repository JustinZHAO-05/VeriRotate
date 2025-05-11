`timescale 1ns/1ps

// Top-level Testbench: 集成所有模块并生成 lena_rot.mem
module Top_TB;
    // Image dimensions
    parameter W = 256;
    parameter H = 256;

    // Clock and reset
    reg              Clk_in;
    reg              Reset_n;

    // TB_InputDriver signals
    wire             Start_in;
    wire             H_Valid_in;
    wire             H_Jump_in;
    wire      [23:0] Bmp_Data;

    // Input_Interface signals
    wire             pixel_ready;
    wire             pixel_valid;
    wire             line_end;
    wire      [23:0] pixel_data;

    // Write_Controller -> SRAM write port
    wire             write_finish;
    wire             SRAM_EN_w;
    wire             SRAM_WE_w;
    wire      [19:0] SRAM_Addr_w;
    wire      [23:0] SRAM_Din;

    // SRAM read port -> Read_Controller
    wire             SRAM_EN_r;
    wire             SRAM_WE_r;
    wire      [19:0] SRAM_Addr_r;
    wire      [23:0] SRAM_Dout;

    // Read_Controller outputs
    wire             out_pixel_ready;
    wire             out_pixel_valid;
    wire             out_line_end;
    wire      [23:0] out_pixel_data;
    wire             read_finish;

    // Output_Interface outputs
    wire             Clk_out;
    wire             Start_out;
    wire             H_Valid_out;
    wire             H_Jump_out;
    wire      [23:0] R_Bmp_Data;

    // Memory to collect output pixels
    reg       [23:0] mem_out [0:W*H-1];
    integer idx,i;
    initial begin
        idx = 0;
        for (i = 0; i < W*H; i = i + 1)
            mem_out[i] = 24'h000000;
    end

    // Instantiate modules
    TB_InputDriver tb_driver(
        .Clk_in     (Clk_in),
        .Start_in   (Start_in),
        .H_Valid_in (H_Valid_in),
        .H_Jump_in  (H_Jump_in),
        .Bmp_Data   (Bmp_Data)
    );

    Input_Interface input_if(
        .Clk_in      (Clk_in),
        .Start_in    (Start_in),
        .H_Valid_in  (H_Valid_in),
        .H_Jump_in   (H_Jump_in),
        .Bmp_Data    (Bmp_Data),
        .pixel_ready (pixel_ready),
        .pixel_valid (pixel_valid),
        .line_end    (line_end),
        .pixel_data  (pixel_data)
    );

    Write_Controller wc(
        .Clk_in        (Clk_in),
        .Reset_n       (Reset_n),
        .pixel_ready   (pixel_ready),
        .pixel_valid   (pixel_valid),
        .line_end      (line_end),
        .pixel_data    (pixel_data),
        .write_finish  (write_finish),
        .SRAM_EN_w     (SRAM_EN_w),
        .SRAM_WE_w     (SRAM_WE_w),
        .SRAM_Addr_w   (SRAM_Addr_w),
        .SRAM_Din      (SRAM_Din)
    );

    SRAM_Model sram(
        .clk      (Clk_in),
        .en       (SRAM_EN_w | SRAM_EN_r),
        .we       (SRAM_WE_w),
        .addr     (SRAM_EN_w ? SRAM_Addr_w : SRAM_Addr_r),
        .data_in  (SRAM_Din),
        .data_out (SRAM_Dout)
    );

    Read_Controller rc(
        .Clk_in           (Clk_in),
        .Reset_n          (Reset_n),
        .write_finish     (write_finish),
        .read_finish      (read_finish),
        .SRAM_EN_r        (SRAM_EN_r),
        .SRAM_WE_r        (SRAM_WE_r),
        .SRAM_Addr_r      (SRAM_Addr_r),
        .SRAM_Dout        (SRAM_Dout),
        .out_pixel_ready  (out_pixel_ready),
        .out_pixel_valid  (out_pixel_valid),
        .out_line_end     (out_line_end),
        .out_pixel_data   (out_pixel_data)
    );

    Output_Interface out_if(
        .Clk_in           (Clk_in),
        .out_pixel_ready  (out_pixel_ready),
        .out_pixel_valid  (out_pixel_valid),
        .out_line_end     (out_line_end),
        .out_pixel_data   (out_pixel_data),
        .Clk_out          (Clk_out),
        .Start_out        (Start_out),
        .H_Valid_out      (H_Valid_out),
        .H_Jump_out       (H_Jump_out),
        .R_Bmp_Data       (R_Bmp_Data)
    );

    // Collect rotated pixels and write to memory file

    reg start_d, start_dd;
    reg hvalid_d, hvalid_dd;
    reg [23:0] data_d, data_dd;

    // pipeline the handshake and data by 2 cycles
    always @(posedge Clk_out) begin
        // shift the valid pulses
        start_d   <= Start_out;
        start_dd  <= start_d;
        hvalid_d  <= H_Valid_out;
        hvalid_dd <= hvalid_d;
        // shift the pixel data
        data_d    <= R_Bmp_Data;
        data_dd   <= data_d;
    end

    // now collect using the delayed signals
    always @(posedge Clk_out) begin
        if (start_dd) begin
            idx = 0;
            mem_out[idx] = data_dd;  // 写第 0 个有效像素
            idx = idx + 1;
        end
        else if (hvalid_dd) begin
            mem_out[idx] = data_dd;
            idx = idx + 1;
        end

        if (idx == W*H) begin
            $writememh("lena_rot.mem", mem_out, 0, W*H-1);
            $display("旋转完成，文件 lena_rot.mem 已生成");
            $stop;
        end
    end


    // Clock generation: 100MHz
    initial begin
        Clk_in = 0;
        forever #5 Clk_in = ~Clk_in;
    end

    // Reset sequence
    initial begin
        Reset_n = 0;
        #20 Reset_n = 1;
    end

endmodule
