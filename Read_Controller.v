`timescale 1ns/1ps

// Read_Controller: FSM that issues read commands to SRAM, applies a two-stage
// pipeline to compensate for synchronous RAM read latency, and outputs
// the pixel stream for the rotated image.
// - Clk_in:  input clock
// - Reset_n: active-low synchronous reset
// - write_finish: input flag indicating all pixels have been written
// 
// Outputs:
// - read_finish:      asserted when all pixels have been read
// - SRAM_EN_r:        SRAM enable for read
// - SRAM_WE_r:        SRAM write-enable (always 0 for read)
// - SRAM_Addr_r:      address bus for reading from SRAM
// - out_pixel_ready:  high for one cycle at the first pixel of the rotated frame
// - out_pixel_valid:  high while pixel_data is valid
// - out_line_end:     high for one cycle at the end of each output line
// - out_pixel_data:   24-bit RGB pixel data after rotation

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
  parameter W = 256, H = 256;              // Image width and height
  localparam R_IDLE = 2'd0,                // Idle state: waiting for write to finish
             R_READ = 2'd1,                // Read state: issuing read requests
             R_DONE = 2'd2;                // Done state: all pixels read
  reg [1:0] state;                         // FSM state register

  // Read pointers (row and column indices of the target rotated image)
  reg [8:0] row_o, col_o;

  // Two-stage pipeline registers to align read address with read data
  reg        en_req, en_dly;               // Stage enable signals
  reg [8:0]  row_req, col_req;             // Coordinates at request time
  reg [8:0]  row_dly, col_dly;             // Coordinates delayed by one cycle

  // Instantiate the address generator for counter-clockwise rotation mapping
  wire [19:0] read_addr;
  Addr_Generator #(.W(W), .H(H)) addr_gen (
    .row_o     (row_o),
    .col_o     (col_o),
    .read_addr (read_addr)
  );

  // Main FSM and pipeline logic
  always @(posedge Clk_in or negedge Reset_n) begin
    if (!Reset_n) begin
      // Reset all registers
      state           <= R_IDLE;
      row_o           <= 0;
      col_o           <= 0;
      en_req          <= 0;
      en_dly          <= 0;
      row_req         <= 0;
      col_req         <= 0;
      row_dly         <= 0;
      col_dly         <= 0;
      read_finish     <= 0;
      SRAM_EN_r       <= 0;
      SRAM_WE_r       <= 0;
      SRAM_Addr_r     <= 0;
      out_pixel_valid <= 0;
      out_pixel_ready <= 0;
      out_line_end    <= 0;
      out_pixel_data  <= 0;
    end else begin
      // Default: deactivate read and output signals
      SRAM_EN_r       <= 0;
      en_req          <= 0;
      out_pixel_valid <= 0;
      out_pixel_ready <= 0;
      out_line_end    <= 0;

      // 1) FSM: control read request sequencing
      case (state)
        R_IDLE: begin
          read_finish <= 0;
          if (write_finish) begin
            // Transition to read state once write is complete
            row_o  <= 0;
            col_o  <= 0;
            state  <= R_READ;
          end
        end

        R_READ: begin
          // Issue a synchronous read to SRAM
          SRAM_EN_r   <= 1;           // Enable read port
          SRAM_WE_r   <= 0;           // Disable write
          SRAM_Addr_r <= read_addr;   // Address from Addr_Generator
          en_req      <= 1;           // Mark this cycle as a valid request
          row_req     <= row_o;       // Capture current coordinates
          col_req     <= col_o;

          // Advance the read pointer
          if (row_o == H-1 && col_o == W-1) begin
            // Last pixel: transition to DONE
            state       <= R_DONE;
            read_finish <= 1;         // Signal completion
          end else if (col_o == W-1) begin
            // End of a row: wrap column, increment row
            col_o <= 0;
            row_o <= row_o + 1;
          end else begin
            // Normal case: next column
            col_o <= col_o + 1;
          end
        end

        R_DONE: begin
          // Stay in DONE, keep read_finish asserted
          read_finish <= 1;
        end

        default: state <= R_IDLE;
      endcase

      // 2) Pipeline stage 1 → stage 2 transfer
      en_dly    <= en_req;
      row_dly   <= row_req;
      col_dly   <= col_req;

      // 3) On delayed enable, capture and output the SRAM data
      if (en_dly) begin
        out_pixel_data  <= SRAM_Dout;               // Data aligned to request
        out_pixel_valid <= 1;                       // Pixel data is valid
        // First-pixel marker when (row, col) == (0,0)
        out_pixel_ready <= (row_dly == 0 && col_dly == 0);
        // End-of-line marker when column wraps
        out_line_end    <= (col_dly == W-1);
      end
    end
  end
endmodule

