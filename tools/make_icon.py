"""Genera l'icona dell'app (originale: tre fader stilizzati) senza librerie esterne."""
import struct, zlib, sys

def png(size):
    px = []
    r = size * 0.18
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            # quadrato arrotondato scuro
            cx = min(max(x, r), size - 1 - r); cy = min(max(y, r), size - 1 - r)
            inside = (x - cx) ** 2 + (y - cy) ** 2 <= r * r
            col = (0, 0, 0, 0)
            if inside:
                col = (22, 26, 34, 255)
                for i, (pos, c) in enumerate([(0.62, (242, 194, 48)), (0.38, (48, 164, 108)), (0.52, (62, 123, 250))]):
                    fx = size * (0.28 + i * 0.22)
                    if abs(x - fx) <= size * 0.025 and size * 0.18 <= y <= size * 0.82:
                        col = (60, 68, 84, 255)
                    ky = size * (0.82 - pos * 0.64)
                    if abs(x - fx) <= size * 0.075 and abs(y - ky) <= size * 0.045:
                        col = c + (255,)
            row += bytes(col)
        px.append(bytes(row))
    raw = b''.join(px)
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')

sizes = [16, 24, 32, 48, 64, 128, 256]
imgs = [png(s) for s in sizes]
out = struct.pack('<HHH', 0, 1, len(sizes))
off = 6 + 16 * len(sizes)
for s, d in zip(sizes, imgs):
    out += struct.pack('<BBBBHHII', s % 256, s % 256, 0, 0, 1, 32, len(d), off); off += len(d)
out += b''.join(imgs)
open(sys.argv[1], 'wb').write(out)
open(sys.argv[1].replace('.ico', '_256.png'), 'wb').write(imgs[-1])
print('ok', len(out))
