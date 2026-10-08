import struct
import zlib
from pathlib import Path


def write_png(path: Path, size=(4, 4), alpha=False, seed=0) -> Path:
    width, height = size
    channels = 4 if alpha else 3
    raw = b"".join(b"\x00" + bytes([(x + seed) % 256 for x in range(width * channels)]) for _ in range(height))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6 if alpha else 2, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
    return path
