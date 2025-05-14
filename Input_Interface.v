`timescale 1ns/1ps

// Input_Interface: Synchronize and register input signals from the Testbench.
// - Receives asynchronous or raw signals: Clk_in, Start_in, H_Valid_in, H_Jump_in, Bmp_Data
// - Produces clean, one-cycle–delayed outputs: pixel_ready, pixel_valid, line_end, pixel_data

module Input_Interface(
    input  wire        Clk_in,        // System clock (100 MHz)
    input  wire        Start_in,      // High for one cycle at the first pixel of the image
    input  wire        H_Valid_in,    // High during each valid pixel period for a row
    input  wire        H_Jump_in,     // High for one cycle at the end of each row
    input  wire [23:0] Bmp_Data,      // 24-bit RGB pixel data from Testbench

    output reg         pixel_ready,   // Synchronized version of Start_in
    output reg         pixel_valid,   // Synchronized version of H_Valid_in
    output reg         line_end,      // Synchronized version of H_Jump_in
    output reg  [23:0] pixel_data     // Synchronized RGB data
);

    // ------------------------------------------------------------------------
    // Internal registers for one-cycle delay (synchronization)
    // ------------------------------------------------------------------------
    reg [23:0] Bmp_Data_d;  // Delayed pixel data
    reg        Start_d;     // Delayed Start_in
    reg        H_Valid_d;   // Delayed H_Valid_in
    reg        H_Jump_d;    // Delayed H_Jump_in

    // ------------------------------------------------------------------------
    // Initial block to clear all registers at simulation start
    // ------------------------------------------------------------------------
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

    // ------------------------------------------------------------------------
    // On each rising edge of Clk_in:
    //  1) Register (delay) all input signals into _d registers.
    //  2) Drive outputs from the delayed registers, ensuring
    //     a clean, glitch-free transfer to downstream logic.
    // ------------------------------------------------------------------------
    always @(posedge Clk_in) begin
        // Stage 1: capture inputs
        Start_d    <= Start_in;
        H_Valid_d  <= H_Valid_in;
        H_Jump_d   <= H_Jump_in;
        Bmp_Data_d <= Bmp_Data;

        // Stage 2: drive outputs from delayed values
        pixel_ready <= Start_d;      // Marks the first pixel of the frame
        pixel_valid <= H_Valid_d;    // Indicates valid pixel data for current row
        line_end    <= H_Jump_d;     // Indicates end of the current row
        pixel_data  <= Bmp_Data_d;   // Provides stable RGB data to Write_Controller
    end

endmodule

