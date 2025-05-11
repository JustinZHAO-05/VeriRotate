This project demonstrates a purely-hardware implementation, in Verilog, of a 90° counter-clockwise rotation on a 24-bit BMP image (e.g. the classic Lena). It is structured as a pipeline of nine distinct modules:

BMP_Preprocessor (Python)
Parses the input BMP file and dumps its pixels (RRGGBB hex) into lena.mem.

TB_InputDriver (Testbench)
Reads lena.mem and generates synchronized pixel-stream signals (Start_in, H_Valid_in, H_Jump_in, Bmp_Data) under a 100 MHz clock.

Input_Interface
Synchronizes and debounces the incoming control and data lines, producing clean pixel_valid, pixel_ready, line_end, and pixel_data.

Write_Controller (FSM)
Captures each incoming pixel and writes it sequentially into synchronous SRAM.

SRAM_Model
A behavioral 24-bit, 65 536-deep memory that holds the entire image.

Read_Controller (FSM + 2-stage pipeline)
After the write phase completes, issues read commands with a one-cycle delay and re-orders addresses so that each output pixel appears in the rotated position.

Addr_Generator
Encapsulates the core “new(r,c) = old(c, W–1–r)” mapping for counter-clockwise rotation.

Output_Interface
Formats the rotated pixel stream back into Start_out, H_Valid_out, H_Jump_out, R_Bmp_Data signals.

Top_TB (Testbench)
Instantiates all modules, collects R_Bmp_Data into an array, and dumps lena_rot.mem once 65 536 pixels are written.

A companion BMP_Postprocessor script reads lena_rot.mem and reconstructs the final lena_rot.bmp, which you can open to verify the 90° counter-clockwise rotation.
