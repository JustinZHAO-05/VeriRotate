`timescale 1ns/1ps

// SRAM_Model: 模拟静态随机存取存储器 (SRAM)
// - 支持同步读写
// - 地址宽度 20-bit, 数据宽度 24-bit
// - 深度支持最大 1M 地址空间，实际使用 256x256=65536

module SRAM_Model (
    input  wire        clk,
    input  wire        en,
    input  wire        we,
    input  wire [19:0] addr,
    input  wire [23:0] data_in,
    output reg  [23:0] data_out
);

    // 内部存储阵列
    reg [23:0] mem [0:65535];

    // 同步读写逻辑
    always @(posedge clk) begin
        if (en) begin
            if (we) begin
                // 写操作
                mem[addr] <= data_in;
            end else begin
                // 读操作
                data_out <= mem[addr];
            end
        end
    end

endmodule