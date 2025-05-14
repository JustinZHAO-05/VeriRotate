`timescale 1ns/1ps

// Top_TB: Top-level testbench that integrates all image-rotation modules.
// It drives the BMP input, instantiates the pipeline, collects rotated pixels,
// and writes them out to a `.mem` file.

module Top_TB;
    // -------------------------------------------------------------
    // Parameters: image dimensions
    // -------------------------------------------------------------
    parameter W = 256;    // Image width in pixels
    parameter H = 256;    // Image height in pixels

    // -------------------------------------------------------------
    // Clock and reset signals
    // -------------------------------------------------------------
    reg Clk_in;          // 100 MHz clock
    reg Reset_n;         // Active-low reset

    // -------------------------------------------------------------
    // Signals from TB_InputDriver
    // -------------------------------------------------------------
    wire        Start_in;     // Frame-start pulse
    wire        H_Valid_in;   // Pixel-valid for each pixel
    wire        H_Jump_in;    // End-of-line pulse
    wire [23:0] Bmp_Data;     // 24-bit RGB pixel from .mem

    // -------------------------------------------------------------
    // Signals from Input_Interface
    // -------------------------------------------------------------
    wire        pixel_ready;  // Synchronized frame-start
    wire        pixel_valid;  // Synchronized pixel-valid
    wire        line_end;     // Synchronized end-of-line
    wire [23:0] pixel_data;   // Synchronized pixel data

    // -------------------------------------------------------------
    // Write_Controller → SRAM write port
    // -------------------------------------------------------------
    wire        write_finish; // Asserted when all writes are done
    wire        SRAM_EN_w;    // SRAM write-enable
    wire        SRAM_WE_w;    // SRAM write-enable signal
    wire [19:0] SRAM_Addr_w;  // SRAM write address
    wire [23:0] SRAM_Din;     // SRAM write data

    // -------------------------------------------------------------
    // SRAM read port → Read_Controller
    // -------------------------------------------------------------
    wire        SRAM_EN_r;    // SRAM read-enable
    wire        SRAM_WE_r;    // SRAM write-enable (should be 0)
    wire [19:0] SRAM_Addr_r;  // SRAM read address
    wire [23:0] SRAM_Dout;    // SRAM read data output

    // -------------------------------------------------------------
    // Read_Controller outputs
    // -------------------------------------------------------------
    wire        out_pixel_ready; // Delayed frame-start for rotated image
    wire        out_pixel_valid; // Delayed pixel-valid for rotated image
    wire        out_line_end;    // Delayed end-of-line for rotated image
    wire [23:0] out_pixel_data;  // Rotated pixel data
    wire        read_finish;     // Asserted when all reads are done

    // -------------------------------------------------------------
    // Output_Interface outputs
    // -------------------------------------------------------------
    wire        Clk_out;      // Forwarded clock to data collector
    wire        Start_out;    // Final frame-start pulse
    wire        H_Valid_out;  // Final pixel-valid
    wire        H_Jump_out;   // Final end-of-line
    wire [23:0] R_Bmp_Data;   // Final rotated pixel data

    // -------------------------------------------------------------
    // Memory array for collecting rotated pixels, plus index
    // -------------------------------------------------------------
    reg [23:0] mem_out [0:W*H-1];  // Buffer to hold 65 536 rotated pixels
    integer idx, i;
    initial begin
        // Initialize the index and clear the buffer
        idx = 0;
        for (i = 0; i < W*H; i = i + 1)
            mem_out[i] = 24'h000000;
    end

    // -------------------------------------------------------------
    // Instantiate the modules and wire them together
    // -------------------------------------------------------------
    TB_InputDriver tb_driver (
        .Clk_in     (Clk_in),
        .Start_in   (Start_in),
        .H_Valid_in (H_Valid_in),
        .H_Jump_in  (H_Jump_in),
        .Bmp_Data   (Bmp_Data)
    );

    Input_Interface input_if (
        .Clk_in      (Clk_in),
        .Start_in    (Start_in),
        .H_Valid_in  (H_Valid_in),
        .H_Jump_in   (H_Jump_in),
        .Bmp_Data    (Bmp_Data),
        .pixel_ready (pixel_ready),
        .pixel_valid (pixel_valid),
        .line_end    (line_end),
        .pixel_data  (pixel_data)
    );

    Write_Controller wc (
        .Clk_in        (Clk_in),
        .Reset_n       (Reset_n),
        .pixel_ready   (pixel_ready),
        .pixel_valid   (pixel_valid),
        .line_end      (line_end),
        .pixel_data    (pixel_data),
        .write_finish  (write_finish),
        .SRAM_EN_w     (SRAM_EN_w),
        .SRAM_WE_w     (SRAM_WE_w),
        .SRAM_Addr_w   (SRAM_Addr_w),
        .SRAM_Din      (SRAM_Din)
    );

    SRAM_Model sram (
        .clk      (Clk_in),
        .en       (SRAM_EN_w | SRAM_EN_r),  // enable if either port active
        .we       (SRAM_WE_w),               // write-enable from write controller
        .addr     (SRAM_EN_w ? SRAM_Addr_w : SRAM_Addr_r),
        .data_in  (SRAM_Din),
        .data_out (SRAM_Dout)
    );

    Read_Controller rc (
        .Clk_in           (Clk_in),
        .Reset_n          (Reset_n),
        .write_finish     (write_finish),
        .read_finish      (read_finish),
        .SRAM_EN_r        (SRAM_EN_r),
        .SRAM_WE_r        (SRAM_WE_r),
        .SRAM_Addr_r      (SRAM_Addr_r),
        .SRAM_Dout        (SRAM_Dout),
        .out_pixel_ready  (out_pixel_ready),
        .out_pixel_valid  (out_pixel_valid),
        .out_line_end     (out_line_end),
        .out_pixel_data   (out_pixel_data)
    );

    Output_Interface out_if (
        .Clk_in           (Clk_in),
        .out_pixel_ready  (out_pixel_ready),
        .out_pixel_valid  (out_pixel_valid),
        .out_line_end     (out_line_end),
        .out_pixel_data   (out_pixel_data),
        .Clk_out          (Clk_out),
        .Start_out        (Start_out),
        .H_Valid_out      (H_Valid_out),
        .H_Jump_out       (H_Jump_out),
        .R_Bmp_Data       (R_Bmp_Data)
    );

    // -------------------------------------------------------------
    // Two-stage pipeline on the output handshake and data, then collection
    // -------------------------------------------------------------
    reg start_d, start_dd;
    reg hvalid_d, hvalid_dd;
    reg [23:0] data_d, data_dd;

    // Pipeline the Start and H_Valid pulses, and the pixel data
    always @(posedge Clk_out) begin
        start_d   <= Start_out;    // Stage 1 delay
        start_dd  <= start_d;      // Stage 2 delay
        hvalid_d  <= H_Valid_out;
        hvalid_dd <= hvalid_d;
        data_d    <= R_Bmp_Data;
        data_dd   <= data_d;
    end

    // Collect rotated pixels into mem_out[] using the delayed signals
    always @(posedge Clk_out) begin
        if (start_dd) begin
            idx = 0;
            mem_out[idx] = data_dd;  // Write the very first rotated pixel
            idx = idx + 1;
        end
        else if (hvalid_dd) begin
            mem_out[idx] = data_dd;  // Write each subsequent pixel
            idx = idx + 1;
        end

        // Once idx reaches W*H, dump the buffer to a .mem file
        if (idx == W*H) begin
            $writememh("lena_rot.mem", mem_out, 0, W*H-1);
            $display("Rotation complete, file lena_rot.mem generated");
            $stop;
        end
    end

    // -------------------------------------------------------------
    // Clock generation: 100 MHz => toggle every 5 ns
    // -------------------------------------------------------------
    initial begin
        Clk_in = 0;
        forever #5 Clk_in = ~Clk_in;
    end

    // -------------------------------------------------------------
    // Reset sequence: hold Reset_n low for 20 ns, then release
    // -------------------------------------------------------------
    initial begin
        Reset_n = 0;
        #20 Reset_n = 1;
    end

endmodule

