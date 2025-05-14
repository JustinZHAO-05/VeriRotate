`timescale 1ns/1ps

// Write_Controller: Finite State Machine (FSM) that writes incoming pixels into SRAM.
// - States: W_IDLE, W_WRITE, W_NEXT_LINE, W_DONE
// - Interfaces with Input_Interface (pixel_ready, pixel_valid, line_end, pixel_data)
//   and drives the SRAM write port signals (SRAM_EN_w, SRAM_WE_w, SRAM_Addr_w, SRAM_Din).

module Write_Controller(
    input  wire        Clk_in,        // System clock
    input  wire        Reset_n,       // Active-low reset
    input  wire        pixel_ready,   // Asserted for the very first pixel
    input  wire        pixel_valid,   // High when pixel_data is valid
    input  wire        line_end,      // Pulse at the end of each input row
    input  wire [23:0] pixel_data,    // 24-bit RGB pixel input

    output reg         write_finish,  // Asserted when all pixels have been written
    // SRAM write interface
    output reg         SRAM_EN_w,     // SRAM enable for write operations
    output reg         SRAM_WE_w,     // SRAM write-enable (active high)
    output reg [19:0]  SRAM_Addr_w,   // SRAM write address (linear)
    output reg [23:0]  SRAM_Din       // SRAM write data (24-bit RGB)
);

    // -------------------------------------------------------------
    // Parameters and state definitions
    // -------------------------------------------------------------
    parameter W = 256;                // Image width
    parameter H = 256;                // Image height
    localparam TOTAL_PIXELS = W * H;  // Total number of pixels

    // FSM state encoding
    localparam [1:0] 
        W_IDLE      = 2'd0,  // Waiting for first pixel_valid
        W_WRITE     = 2'd1,  // Writing pixel_data into SRAM
        W_NEXT_LINE = 2'd2,  // End-of-line handling
        W_DONE      = 2'd3;  // All pixels written
    reg [1:0] state;         // Current FSM state

    // Linear address counter for writing pixels sequentially
    reg [19:0] write_addr;   // Ranges 0 to TOTAL_PIXELS-1

    // -------------------------------------------------------------
    // Main FSM: synchronous on rising clock or asynchronous reset
    // -------------------------------------------------------------
    always @(posedge Clk_in or negedge Reset_n) begin
        if (!Reset_n) begin
            // Reset all control signals and counters
            state         <= W_IDLE;
            write_addr    <= 0;
            write_finish  <= 0;
            SRAM_EN_w     <= 0;
            SRAM_WE_w     <= 0;
            SRAM_Addr_w   <= 0;
            SRAM_Din      <= 0;
        end else begin
            case (state)
                // -----------------------------------------------------
                // W_IDLE: wait for the first valid pixel
                // -----------------------------------------------------
                W_IDLE: begin
                    write_finish <= 0;
                    SRAM_EN_w    <= 0;
                    SRAM_WE_w    <= 0;
                    if (pixel_valid) begin
                        // First pixel arrives: perform first write
                        SRAM_EN_w    <= 1;            // Enable SRAM
                        SRAM_WE_w    <= 1;            // Set write mode
                        SRAM_Addr_w  <= 0;            // Address 0
                        SRAM_Din     <= pixel_data;   // Data for address 0
                        write_addr   <= 1;            // Next address
                        state        <= W_WRITE;      // Move to write state
                    end
                end

                // -----------------------------------------------------
                // W_WRITE: write incoming pixels while pixel_valid is high
                // -----------------------------------------------------
                W_WRITE: begin
                    if (pixel_valid) begin
                        // Write each new pixel to the next address
                        SRAM_EN_w    <= 1;
                        SRAM_WE_w    <= 1;
                        SRAM_Addr_w  <= write_addr;
                        SRAM_Din     <= pixel_data;
                        write_addr   <= write_addr + 1;
                        state        <= W_WRITE;      // Remain in write state
                    end else if (line_end) begin
                        // Pixel_valid went low at row end: finish row
                        SRAM_EN_w    <= 0;
                        SRAM_WE_w    <= 0;
                        state        <= W_NEXT_LINE;  // Handle next line
                    end else begin
                        // Optional idle cycle between pixels
                        SRAM_EN_w    <= 0;
                        SRAM_WE_w    <= 0;
                        state        <= W_WRITE;
                    end
                end

                // -----------------------------------------------------
                // W_NEXT_LINE: check if all pixels are written or wait
                // -----------------------------------------------------
                W_NEXT_LINE: begin
                    if (write_addr == TOTAL_PIXELS) begin
                        // All pixels written: signal finish
                        write_finish <= 1;
                        SRAM_EN_w    <= 0;
                        SRAM_WE_w    <= 0;
                        state        <= W_DONE;
                    end else if (pixel_valid) begin
                        // Next row's first pixel: write it
                        SRAM_EN_w    <= 1;
                        SRAM_WE_w    <= 1;
                        SRAM_Addr_w  <= write_addr;
                        SRAM_Din     <= pixel_data;
                        write_addr   <= write_addr + 1;
                        state        <= W_WRITE;
                    end else begin
                        // Wait for the next pixel_valid pulse
                        SRAM_EN_w    <= 0;
                        SRAM_WE_w    <= 0;
                        state        <= W_NEXT_LINE;
                    end
                end

                // -----------------------------------------------------
                // W_DONE: remain in this state once complete
                // -----------------------------------------------------
                W_DONE: begin
                    write_finish <= 1;  // Keep completion flag asserted
                    SRAM_EN_w    <= 0;
                    SRAM_WE_w    <= 0;
                    state        <= W_DONE;
                end

                // -----------------------------------------------------
                // Default safe state
                // -----------------------------------------------------
                default: begin
                    state <= W_IDLE;
                end
            endcase
        end
    end

endmodule

