`timescale 1ns/1ps

// Output_Interface: Format and forward the rotated pixel stream from Read_Controller to the Top-level Testbench.
// - Receives the rotated-pixel handshake and data signals from Read_Controller.
// - Drives the output clock, start pulse, pixel-valid, line-end, and pixel-data signals for downstream capture.

module Output_Interface(
    input  wire        Clk_in,             // Input system clock (from Read_Controller)
    input  wire        out_pixel_ready,    // Indicates the first pixel of the rotated image
    input  wire        out_pixel_valid,    // High during each valid pixel period
    input  wire        out_line_end,       // High for one cycle at the end of each output row
    input  wire [23:0] out_pixel_data,     // 24-bit RGB pixel data from Read_Controller

    output wire        Clk_out,            // Forwarded clock to Top_TB for data collection
    output reg         Start_out,          // Output start-of-frame pulse (one cycle)
    output reg         H_Valid_out,        // Output pixel-valid signal
    output reg         H_Jump_out,         // Output end-of-line pulse
    output reg  [23:0] R_Bmp_Data          // Output rotated RGB pixel data
);

    // ------------------------------------------------------------------------
    // Simply forward the input clock to the output clock port.
    // This ensures that Top_TB sees the same timing reference.
    // ------------------------------------------------------------------------
    assign Clk_out = Clk_in;

    // ------------------------------------------------------------------------
    // Initialize all output registers to zero at simulation start.
    // ------------------------------------------------------------------------
    initial begin
        Start_out    = 0;
        H_Valid_out  = 0;
        H_Jump_out   = 0;
        R_Bmp_Data   = 0;
    end

    // ------------------------------------------------------------------------
    // On each rising edge of Clk_in:
    //  - Sample the incoming rotated-pixel handshake and data signals
    //    and register them to the output ports.
    //  - This provides one-cycle synchronization to the Top-level Testbench.
    // ------------------------------------------------------------------------
    always @(posedge Clk_in) begin
        Start_out   <= out_pixel_ready;  // Propagate the start-of-frame marker
        H_Valid_out <= out_pixel_valid;  // Propagate pixel-valid for each RGB sample
        H_Jump_out  <= out_line_end;     // Propagate end-of-line marker
        R_Bmp_Data  <= out_pixel_data;   // Propagate the 24-bit rotated pixel
    end

endmodule
