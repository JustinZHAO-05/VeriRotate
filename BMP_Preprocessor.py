#!/usr/bin/env python3
"""
BMP_Preprocessor: Parse a 24-bit BMP image into a one-dimensional pixel array
and emit it as a hex text file. Each line contains one 24-bit RGB value
in RRGGBB format, suitable for Verilog Testbench’s $readmemh.
"""

import sys
import os

def bmp_to_mem(input_bmp: str, output_mem: str):
    # -------------------------------------------------------------------------
    # 1. Read and validate the BMP header (first 54 bytes)
    # -------------------------------------------------------------------------
    with open(input_bmp, 'rb') as f:
        header = f.read(54)
        # Ensure we got exactly 54 bytes for the BITMAPFILEHEADER + BITMAPINFOHEADER
        if len(header) != 54:
            raise ValueError("Not a standard 54-byte BMP header")
        # Byte offset where the pixel data actually begins (bytes 10–13, little endian)
        data_offset = int.from_bytes(header[10:14], 'little')
        # Image width in pixels (bytes 18–21, little endian)
        width  = int.from_bytes(header[18:22], 'little')
        # Image height in pixels (bytes 22–25, little endian)
        height = int.from_bytes(header[22:26], 'little')
        # Bits per pixel (bytes 28–29, little endian); we expect 24
        bpp    = int.from_bytes(header[28:30], 'little')
    
    # Only 24-bit BMPs are supported
    if bpp != 24:
        raise ValueError(f"Only 24-bit BMP supported, but found bpp={bpp}")

    # Each scanline is padded to a multiple of 4 bytes in BMP files
    row_size = ((width * 3 + 3) // 4) * 4

    # -------------------------------------------------------------------------
    # 2. Read the raw pixel data (stored bottom-to-top in BMP format)
    # -------------------------------------------------------------------------
    pixels = []
    with open(input_bmp, 'rb') as f:
        # Seek to the start of pixel data
        f.seek(data_offset)
        # Read each scanline
        for _ in range(height):
            raw = f.read(row_size)
            # Extract BGR triples for each pixel in this row
            for x in range(width):
                b = raw[x*3]       # Blue channel
                g = raw[x*3 + 1]   # Green channel
                r = raw[x*3 + 2]   # Red channel
                pixels.append((r, g, b))

    # -------------------------------------------------------------------------
    # 3. Reorder from BMP bottom-to-top into a top-to-bottom array
    # -------------------------------------------------------------------------
    pixels_top_down = []
    for row in range(height - 1, -1, -1):
        start = row * width
        pixels_top_down.extend(pixels[start:start + width])

    # -------------------------------------------------------------------------
    # 4. Write out the .mem file: one RRGGBB hex value per line
    # -------------------------------------------------------------------------
    with open(output_mem, 'w') as fout:
        for (r, g, b) in pixels_top_down:
            # Format each channel as two uppercase hex digits
            fout.write(f"{r:02X}{g:02X}{b:02X}\n")

    print(f"Generated '{output_mem}', total pixels = {width * height}")

if __name__ == "__main__":
    # Simple command-line interface: expect two arguments
    if len(sys.argv) != 3:
        print("Usage: python bmp_preprocessor.py <input.bmp> <output.mem>")
        sys.exit(1)
    bmp_to_mem(sys.argv[1], sys.argv[2])
