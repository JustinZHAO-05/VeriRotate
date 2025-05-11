`timescale 1ns/1ps

// Output_Interface: 格式化并输出旋转后像素信号给Testbench
// - 接收Read_Controller的像素及握手信号
// - 输出Cl k_out, Start_out, H_Valid_out, H_Jump_out, R_Bmp_Data

module Output_Interface(
    input  wire        Clk_in,
    input  wire        out_pixel_ready,
    input  wire        out_pixel_valid,
    input  wire        out_line_end,
    input  wire [23:0] out_pixel_data,

    output wire        Clk_out,
    output reg         Start_out,
    output reg         H_Valid_out,
    output reg         H_Jump_out,
    output reg  [23:0] R_Bmp_Data
);

    // 直接绑定时钟输出
    assign Clk_out = Clk_in;

    // 初始值
    initial begin
        Start_out    = 0;
        H_Valid_out  = 0;
        H_Jump_out   = 0;
        R_Bmp_Data   = 0;
    end

    // 在时钟上升沿采样并输出信号
    always @(posedge Clk_in) begin
        Start_out    <= out_pixel_ready;
        H_Valid_out  <= out_pixel_valid;
        H_Jump_out   <= out_line_end;
        R_Bmp_Data   <= out_pixel_data;
    end

endmodule