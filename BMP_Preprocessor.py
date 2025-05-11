# BMP Preprocessor: Python 实现


#!/usr/bin/env python3
"""
BMP_Preprocessor: 将 24-bit BMP 图片解析为一维像素数组（hex 文本格式）
输出每行一个 24-bit RGB 值（RRGGBB），用于 Verilog Testbench 的 $readmemh。
"""

import sys
import os

def bmp_to_mem(input_bmp: str, output_mem: str):
    # 读取 BMP 头
    with open(input_bmp, 'rb') as f:
        header = f.read(54)
        if len(header) != 54:
            raise ValueError("不是标准的 54-byte BMP 头")
        # 文件数据偏移
        data_offset = int.from_bytes(header[10:14], 'little')
        # 宽、高
        width = int.from_bytes(header[18:22], 'little')
        height = int.from_bytes(header[22:26], 'little')
        # 每像素位深
        bpp = int.from_bytes(header[28:30], 'little')
    
    if bpp != 24:
        raise ValueError(f"只支持 24-bit BMP，当前 bpp={bpp}")
    # 每行实际占用字节（4-byte 对齐）
    row_size = ((width * 3 + 3) // 4) * 4

    # 读取像素数据（BMP 从底行开始存储）
    pixels = []
    with open(input_bmp, 'rb') as f:
        f.seek(data_offset)
        for row in range(height):
            raw = f.read(row_size)
            # 逐像素提取 BGR
            for x in range(width):
                b = raw[x*3]
                g = raw[x*3 + 1]
                r = raw[x*3 + 2]
                pixels.append((r, g, b))

    # 将底-顶行顺序转换为顶-底行顺序
    pixels_top_down = []
    for row in range(height - 1, -1, -1):
        start = row * width
        pixels_top_down.extend(pixels[start:start + width])

    # 写出 .mem 文件
    with open(output_mem, 'w') as fout:
        for (r, g, b) in pixels_top_down:
            fout.write(f"{r:02X}{g:02X}{b:02X}\n")
    print(f"已生成 {output_mem}, 像素总数 = {width*height}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("用法: python bmp_preprocessor.py input.bmp output.mem")
        sys.exit(1)
    bmp_to_mem(sys.argv[1], sys.argv[2])
