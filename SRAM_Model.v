`timescale 1ns/1ps

// SRAM_Model: Behavioral model of a synchronous Static RAM (SRAM).
// - Supports synchronous read and write operations.
// - Address width: 20 bits (up to 1M locations, though only 65,536 used).
// - Data width: 24 bits per location (one RGB pixel).
// - Intended depth: W x H = 256 x 256 = 65,536 entries.

module SRAM_Model (
    input  wire        clk,      // Clock input: operations occur on rising edge
    input  wire        en,       // Enable: when low, no read or write
    input  wire        we,       // Write enable: when high performs write, else read
    input  wire [19:0] addr,     // Address bus: selects which memory location to access
    input  wire [23:0] data_in,  // Data input bus (for write operations)
    output reg  [23:0] data_out  // Data output bus (for read operations)
);

    // Internal memory array: depth 65,536 words of 24 bits each.
    reg [23:0] mem [0:65535];

    // Synchronous read/write logic:
    //  - On each rising edge of clk, if en==1:
    //      * If we==1: write data_in into mem at address 'addr'.
    //      * Else: read mem at 'addr' into data_out.
    always @(posedge clk) begin
        if (en) begin
            if (we) begin
                // Write operation: store data_in into memory.
                mem[addr] <= data_in;
            end else begin
                // Read operation: output the data from memory.
                data_out <= mem[addr];
            end
        end
        // If en==0, retain previous data_out and do not modify memory.
    end

endmodule
