`timescale 1ns/1ps

// Addr_Generator: 根据输出行列(row_o, col_o)组合逻辑生成旋转后读地址
// 实现逆时针90°映射：read_addr = (W-1-col_o)*W + row_o

module Addr_Generator(
    input  wire [8:0]  row_o,       // 0..H-1
    input  wire [8:0]  col_o,       // 0..W-1
    output wire [19:0] read_addr    // 0..W*H-1
);

    parameter W = 256;
    parameter H = 256;

    // 计算读地址
    assign read_addr = col_o * W + (W - 1 - row_o);

endmodule
