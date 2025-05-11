`timescale 1ns/1ps

// Input_Interface: 处理并同步Testbench输入信号
// - 接收Clkin, Start_in, H_Valid_in, H_Jump_in, Bmp_Data
// - 输出pixel_ready, pixel_valid, line_end, pixel_data

module Input_Interface(
    input  wire        Clk_in,
    input  wire        Start_in,
    input  wire        H_Valid_in,
    input  wire        H_Jump_in,
    input  wire [23:0] Bmp_Data,

    output reg         pixel_ready,
    output reg         pixel_valid,
    output reg         line_end,
    output reg  [23:0] pixel_data
);

    // 一周期延迟寄存，用于同步
    reg Start_d;
    reg H_Valid_d;
    reg H_Jump_d;
    reg [23:0] Bmp_Data_d;

    // 初始清零
    initial begin
        Start_d      = 0;
        H_Valid_d    = 0;
        H_Jump_d     = 0;
        Bmp_Data_d   = 0;
        pixel_ready  = 0;
        pixel_valid  = 0;
        line_end     = 0;
        pixel_data   = 0;
    end

    // 同步寄存与输出
    always @(posedge Clk_in) begin
        // 延迟输入信号
        Start_d    <= Start_in;
        H_Valid_d  <= H_Valid_in;
        H_Jump_d   <= H_Jump_in;
        Bmp_Data_d <= Bmp_Data;

        // 输出同步后的信号
        pixel_ready <= Start_d;
        pixel_valid <= H_Valid_d;
        line_end    <= H_Jump_d;
        pixel_data  <= Bmp_Data_d;
    end

endmodule
