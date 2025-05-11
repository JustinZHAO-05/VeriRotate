`timescale 1ns/1ps

// TB_InputDriver: 驱动 BMP 输入信号
// - 读取 lena.mem
// - 生成 Start_in, H_Valid_in, H_Jump_in, Bmp_Data
// Clk_in 由顶层提供

module TB_InputDriver(
    input  wire        Clk_in,
    output reg         Start_in,
    output reg         H_Valid_in,
    output reg         H_Jump_in,
    output reg [23:0]  Bmp_Data
);

    parameter W = 256;
    parameter H = 256;

    // 像素缓存
    reg [23:0] mem [0:W*H-1];
    integer    row, col;

    // 读入像素数据
    initial begin
        $readmemh("lena.mem", mem);
    end

    // 驱动像素流
    initial begin
        Start_in    = 0;
        H_Valid_in  = 0;
        H_Jump_in   = 0;
        Bmp_Data    = 0;

        #100; // 全局复位等待

        // 第一个像素
        Start_in    = 1;
        H_Valid_in  = 1;
        Bmp_Data    = mem[0];
        @(posedge Clk_in);
        Start_in    = 0;

        // 按行列输出像素
        for (row = 0; row < H; row = row + 1) begin
            for (col = 0; col < W; col = col + 1) begin
                if (!(row == 0 && col == 0)) begin
                    Bmp_Data   = mem[row*W + col];
                    H_Valid_in = 1;
                    H_Jump_in  = 0;
                    @(posedge Clk_in);
                end
            end
            // 行结束
            H_Valid_in = 0;
            H_Jump_in  = 1;
            @(posedge Clk_in);
            H_Jump_in  = 0;
        end

        // 结束后复位
        H_Valid_in = 0;
        H_Jump_in  = 0;
        Bmp_Data   = 0;
    end

endmodule
