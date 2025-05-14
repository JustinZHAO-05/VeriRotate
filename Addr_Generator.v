`timescale 1ns/1ps

// Addr_Generator: Compute the SRAM read address for a 90° counter-clockwise rotation.
// Given an output pixel coordinate (row_o, col_o), this module calculates the
// corresponding linear address in the original image (row-major order).
//
// Rotation mapping:
//   Output coordinate (r, c) ←→ Original coordinate (c, W-1-r)
//   Linear address = original_row * W + original_col

module Addr_Generator(
    input  wire [8:0]  row_o,       // Output row index, range 0 to H-1
    input  wire [8:0]  col_o,       // Output column index, range 0 to W-1
    output wire [19:0] read_addr    // Computed read address into original image memory
);

    parameter W = 256;             // Image width (pixels)
    parameter H = 256;             // Image height (pixels)

    // Address calculation:
    //   orig_row = col_o
    //   orig_col = W - 1 - row_o
    //   read_addr = orig_row * W + orig_col
    assign read_addr = col_o * W + (W - 1 - row_o);

endmodule

