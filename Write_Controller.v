`timescale 1ns/1ps

// Write_Controller: FSM for writing incoming pixels into SRAM
// - States: W_IDLE, W_WRITE, W_NEXT_LINE, W_DONE
// - Interfaces with Input_Interface and SRAM_Model write port

module Write_Controller(
    input  wire        Clk_in,
    input  wire        Reset_n,
    input  wire        pixel_ready,
    input  wire        pixel_valid,
    input  wire        line_end,
    input  wire [23:0] pixel_data,

    output reg         write_finish,
    // SRAM write interface
    output reg         SRAM_EN_w,
    output reg         SRAM_WE_w,
    output reg [19:0]  SRAM_Addr_w,
    output reg [23:0]  SRAM_Din
);

    // Image dimensions
    parameter W = 256;
    parameter H = 256;
    localparam TOTAL_PIXELS = W * H;

    // FSM state encoding (use localparam for Verilog-2001 compatibility)
    localparam [1:0] W_IDLE      = 2'd0,
                     W_WRITE     = 2'd1,
                     W_NEXT_LINE = 2'd2,
                     W_DONE      = 2'd3;
    reg [1:0] state;

    // Linear write address counter
    reg [19:0] write_addr;

    // FSM and write logic
    always @(posedge Clk_in or negedge Reset_n) begin
        if (!Reset_n) begin
            state         <= W_IDLE;
            write_addr    <= 0;
            write_finish  <= 0;
            SRAM_EN_w     <= 0;
            SRAM_WE_w     <= 0;
            SRAM_Addr_w   <= 0;
            SRAM_Din      <= 0;
        end else begin
            case (state)
                W_IDLE: begin
                    write_finish <= 0;
                    SRAM_EN_w    <= 0;
                    SRAM_WE_w    <= 0;
                    if (pixel_valid) begin
                        // First pixel write
                        SRAM_EN_w    <= 1;
                        SRAM_WE_w    <= 1;
                        SRAM_Addr_w  <= 0;
                        SRAM_Din     <= pixel_data;
                        write_addr   <= 1;
                        state        <= W_WRITE;
                    end
                end

                W_WRITE: begin
                    if (pixel_valid) begin
                        // Continue writing pixels
                        SRAM_EN_w    <= 1;
                        SRAM_WE_w    <= 1;
                        SRAM_Addr_w  <= write_addr;
                        SRAM_Din     <= pixel_data;
                        write_addr   <= write_addr + 1;
                        state        <= W_WRITE;
                    end else if (line_end) begin
                        // End of line, prepare next line or finish
                        SRAM_EN_w    <= 0;
                        SRAM_WE_w    <= 0;
                        state        <= W_NEXT_LINE;
                    end else begin
                        // Idle between pixels (optional)
                        SRAM_EN_w    <= 0;
                        SRAM_WE_w    <= 0;
                        state        <= W_WRITE;
                    end
                end

                W_NEXT_LINE: begin
                    if (write_addr == TOTAL_PIXELS) begin
                        // All pixels written
                        write_finish <= 1;
                        SRAM_EN_w    <= 0;
                        SRAM_WE_w    <= 0;
                        state        <= W_DONE;
                    end else if (pixel_valid) begin
                        // Next line first pixel
                        SRAM_EN_w    <= 1;
                        SRAM_WE_w    <= 1;
                        SRAM_Addr_w  <= write_addr;
                        SRAM_Din     <= pixel_data;
                        write_addr   <= write_addr + 1;
                        state        <= W_WRITE;
                    end else begin
                        // Wait for next pixel
                        SRAM_EN_w    <= 0;
                        SRAM_WE_w    <= 0;
                        state        <= W_NEXT_LINE;
                    end
                end

                W_DONE: begin
                    // Stay here once done
                    write_finish <= 1;
                    SRAM_EN_w    <= 0;
                    SRAM_WE_w    <= 0;
                    state        <= W_DONE;
                end

                default: begin
                    state <= W_IDLE;
                end
            endcase
        end
    end

endmodule
