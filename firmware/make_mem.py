import sys
import struct

if len(sys.argv) != 3:
    print("Usage: make_mem.py prog.bin mem_init.mem")
    sys.exit(1)

prog_bin = sys.argv[1]
out_mem = sys.argv[2]

# Đọc chương trình
with open(prog_bin, "rb") as f:
    prog = f.read()

# Padding cho đủ bội số 4 byte (1 word 32-bit)
pad = (-len(prog)) % 4   # số byte cần thêm để chia hết cho 4
if pad:
    prog += b"\x00" * pad

prog_words = len(prog) // 4

with open(out_mem, "w") as f:
    for i in range(prog_words):
        # Lấy từng word 4 byte, little-endian
        w = struct.unpack_from("<I", prog, i * 4)[0]
        f.write("{:08x}\n".format(w))

print("Wrote", out_mem, "words:", prog_words)

