`timescale 1ns/1ps

// TB_InputDriver: Testbench module that reads a pixel memory file and
// drives the input handshake and pixel data signals for the hardware pipeline.
// - Uses $readmemh to load 'lena.mem' into an internal array
// - Generates Start_in, H_Valid_in, H_Jump_in, and Bmp_Data on a provided clock
//   Clk_in is driven externally by the top-level testbench.

module TB_InputDriver(
    input  wire        Clk_in,       // Input clock, provided by Top_TB
    output reg         Start_in,     // Pulse for the very first pixel of the frame
    output reg         H_Valid_in,   // High for each valid pixel period on a row
    output reg         H_Jump_in,    // Pulse at the end of each row
    output reg [23:0]  Bmp_Data      // 24-bit RGB pixel data bus
);

    // -------------------------------------------------------------
    // Parameters for image dimensions
    // -------------------------------------------------------------
    parameter W = 256;               // Image width (pixels)
    parameter H = 256;               // Image height (pixels)

    // -------------------------------------------------------------
    // Internal memory array to hold all pixel values from 'lena.mem'
    // -------------------------------------------------------------
    reg [23:0] mem [0:W*H-1];        // Each element is one 24-bit pixel
    integer row, col;                // Loop indices for rows and columns

    // -------------------------------------------------------------
    // Initial block: load the pixel data from an external .mem file
    // -------------------------------------------------------------
    initial begin
        // lena.mem must contain W*H lines of 6-digit hex values (RRGGBB)
        $readmemh("lena.mem", mem);
    end

    // -------------------------------------------------------------
    // Initial block: drive the pixel stream using handshake signals
    // -------------------------------------------------------------
    initial begin
        // Initialize all outputs to zero
        Start_in   = 0;
        H_Valid_in = 0;
        H_Jump_in  = 0;
        Bmp_Data   = 0;

        // Wait for 100 time units to allow any global reset to finish
        #100;

        // ---------------------------------------------------------
        // Send the first pixel of the frame
        // ---------------------------------------------------------
        Start_in   = 1;             // One-cycle pulse to indicate first pixel
        H_Valid_in = 1;             // Indicate pixel data is valid
        Bmp_Data   = mem[0];        // Pixel at index 0
        @(posedge Clk_in);          // Wait one clock cycle
        Start_in   = 0;             // Clear the start pulse

        // ---------------------------------------------------------
        // Stream out the rest of the pixels, row by row
        // ---------------------------------------------------------
        for (row = 0; row < H; row = row + 1) begin
            for (col = 0; col < W; col = col + 1) begin
                // Skip the very first pixel which was already sent
                if (!(row == 0 && col == 0)) begin
                    Bmp_Data   = mem[row*W + col];  // Next pixel value
                    H_Valid_in = 1;                 // Signal valid data
                    H_Jump_in  = 0;                 // Not end of row yet
                    @(posedge Clk_in);              // Advance one cycle
                end
            end
            // -----------------------------------------------------
            // End of current row: deassert valid, pulse H_Jump_in
            // -----------------------------------------------------
            H_Valid_in = 0;        // No more valid pixels this cycle
            H_Jump_in  = 1;        // One-cycle pulse to mark end of row
            @(posedge Clk_in);     // Wait one clock
            H_Jump_in  = 0;        // Clear the row-end pulse
        end

        // ---------------------------------------------------------
        // After streaming all pixels, deassert everything
        // ---------------------------------------------------------
        H_Valid_in = 0;
        H_Jump_in  = 0;
        Bmp_Data   = 0;
    end

endmodule

