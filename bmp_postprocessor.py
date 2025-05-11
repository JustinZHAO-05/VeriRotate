# bmp_postprocessor.py

#!/usr/bin/env python3
"""
BMP_Postprocessor: 根据旋转后的一维像素数组 (.mem) 重建 BMP 图像。
输入：
  - 原始 BMP 文件 (input_bmp)，用于拷贝头部信息
  - 旋转后像素 mem 文件 (input_mem)，由 Verilog 测试平台生成
输出：
  - 输出 BMP 文件 (output_bmp)
"""

import sys

def postprocess_bmp(input_bmp: str, input_mem: str, output_bmp: str):
    # 读取 BMP 头
    with open(input_bmp, 'rb') as f:
        header = f.read(54)
        if len(header) != 54:
            raise ValueError("不是标准的 54-byte BMP 头")
        data_offset = int.from_bytes(header[10:14], 'little')
        width = int.from_bytes(header[18:22], 'little')
        height = int.from_bytes(header[22:26], 'little')
        bpp = int.from_bytes(header[28:30], 'little')
    if bpp != 24:
        raise ValueError(f"只支持 24-bit BMP，当前 bpp={bpp}")

    # 读取 mem 文件，像素按照顶行到底行顺序存储
    pixels = []
    hex_digits = set("0123456789abcdefABCDEF")
    with open(input_mem, 'r') as f:
        for line in f:
            line = line.strip()
            # 跳过空行、注释行或地址标记行
            if not line or line.startswith('//') or line.startswith('@'):
                continue
            # 只保留恰好 6 位的十六进制数据
            if len(line) == 6 and all(c in hex_digits for c in line):
                val = int(line, 16)
                # 拆分为 (r, g, b)
                r = (val >> 16) & 0xFF
                g = (val >> 8)  & 0xFF
                b = val         & 0xFF
                pixels.append((r, g, b))

    # 每行实际字节数 (4-byte 对齐)
    row_size = ((width * 3 + 3) // 4) * 4
    padding = row_size - width * 3

    # 写出新的 BMP
    with open(output_bmp, 'wb') as fout:
        # 写头部
        fout.write(header)
        # 写像素数据 (BMP 存储自下而上)
        for row in range(height - 1, -1, -1):
            for col in range(width):
                r, g, b = pixels[row * width + col]
                fout.write(bytes([b, g, r]))  # BMP 存储顺序为 BGR
            # 行末填充
            fout.write(b'\x00' * padding)

    print(f"已生成旋转后 BMP: {output_bmp}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python bmp_postprocessor.py input.bmp input.mem output.bmp")
        sys.exit(1)
    postprocess_bmp(sys.argv[1], sys.argv[2], sys.argv[3])
