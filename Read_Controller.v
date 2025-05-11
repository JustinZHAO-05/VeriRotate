`timescale 1ns/1ps
module Read_Controller(
    input  wire        Clk_in,
    input  wire        Reset_n,
    input  wire        write_finish,

    output reg         read_finish,
    output reg         SRAM_EN_r,
    output reg         SRAM_WE_r,
    output reg [19:0]  SRAM_Addr_r,
    input  wire [23:0] SRAM_Dout,
    output reg         out_pixel_ready,
    output reg         out_pixel_valid,
    output reg         out_line_end,
    output reg [23:0]  out_pixel_data
);
  parameter W = 256, H = 256;
  localparam R_IDLE = 2'd0, R_READ = 2'd1, R_DONE = 2'd2;
  reg [1:0] state;

  // 读指针
  reg [8:0] row_o, col_o;

  // 两级流水线寄存器
  reg        en_req, en_dly;
  reg [8:0]  row_req, col_req;
  reg [8:0]  row_dly, col_dly;

     // 实例化 Addr_Generator
    wire [19:0] read_addr;
    Addr_Generator #(.W(W), .H(H))
      addr_gen (
        .row_o    (row_o),
        .col_o    (col_o),
        .read_addr(read_addr)
    );


  always @(posedge Clk_in or negedge Reset_n) begin
    if (!Reset_n) begin
      state        <= R_IDLE;
      row_o        <= 0; col_o  <= 0;
      en_req       <= 0; en_dly <= 0;
      row_req      <= 0; col_req<= 0;
      row_dly      <= 0; col_dly<= 0;
      read_finish  <= 0;
      SRAM_EN_r    <= 0; SRAM_WE_r <= 0; SRAM_Addr_r <= 0;
      out_pixel_valid <= 0; out_pixel_ready <= 0; out_line_end <= 0;
      out_pixel_data  <= 0;
    end else begin
      // 默认关闭信号
      SRAM_EN_r <= 0;
      en_req    <= 0;
      out_pixel_valid <= 0;
      out_pixel_ready <= 0;
      out_line_end    <= 0;

      // 1) 管理 FSM
      case(state)
        R_IDLE: begin
          read_finish <= 0;
          if (write_finish) begin
            row_o  <= 0; col_o <= 0;
            state  <= R_READ;
          end
        end

        R_READ: begin
          // 发出读请求
          SRAM_EN_r    <= 1;
          SRAM_WE_r    <= 0;
          SRAM_Addr_r  <= read_addr;
          en_req       <= 1;
          row_req      <= row_o;
          col_req      <= col_o;

          // 推进指针
          if (row_o == H-1 && col_o == W-1) begin
            state       <= R_DONE;
            read_finish <= 1;
          end else if (col_o == W-1) begin
            col_o <= 0;
            row_o <= row_o + 1;
          end else begin
            col_o <= col_o + 1;
          end
        end

        R_DONE: begin
          read_finish <= 1;
          // 保持 state
        end
      endcase

      // 2) 管道第一级→第二级
      en_dly  <= en_req;
      row_dly <= row_req;
      col_dly <= col_req;

      // 3) 延迟一级后采集数据
      if (en_dly) begin
        out_pixel_data  <= SRAM_Dout;
        out_pixel_valid <= 1;
        out_pixel_ready <= (row_dly == 0 && col_dly == 0);
        out_line_end    <= (col_dly == W-1);
      end
    end
  end
endmodule
