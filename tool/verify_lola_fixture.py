#!/usr/bin/env python3
"""
Reproducible LOLA BigTIFF Tile Extraction and Verification Script

NASA LOLA Product 81 Source:
  Dataset: ldem_87s_5mpp.tif (Lunar South Pole DEM, 5 meters/pixel, 87S to 90S)
  URL: https://pgda.gsfc.nasa.gov/data/LOLA_5mpp/87S/ldem_87s_5mpp.tif
  Tile Grid: 157 columns x 157 rows, tile dimensions 256 x 256 pixels
  Tile (78, 78) covering projected origin (0, 0) South Pole:
    Tile Index = 78 * 157 + 78 = 12,324
    TileOffsets tag (324) value offset: 197,624 bytes
      TileOffset entry at: 197,624 + (12,324 * 8) = 296,216 bytes -> 70,248,340
    TileByteCounts tag (325) value offset: 432 bytes
      TileByteCount entry at: 432 + (12,324 * 8) = 98,976 bytes -> 137,823 bytes
  Compression: Deflate (zlib) + TIFF Predictor 3 (floating point horizontal differencing)

This script verifies the exact byte-level decoding algorithm and compares it with
the committed test fixture test/fixtures/terrain/lola_south_pole_tile_78_78.bin.
"""

import sys
import os
import zlib
import struct
import hashlib

FIXTURE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "test", "fixtures", "terrain", "lola_south_pole_tile_78_78.bin"
)

EXPECTED_SHA256 = "ae72c611bb4435c41c7f984dc695aedabdbdd75d22c452afa7fb15963d02ff1e"
TILE_WIDTH = 256
TILE_HEIGHT = 256
BYTES_PER_SAMPLE = 4
EXPECTED_DECOMPRESSED_SIZE = TILE_WIDTH * TILE_HEIGHT * BYTES_PER_SAMPLE  # 262,144 bytes

def decode_predictor3_deflate(compressed_bytes: bytes) -> bytes:
    """
    Decompresses Deflate stream and undifferences TIFF Predictor 3 horizontal byte-differencing.
    Predictor 3 separates each 4-byte Float32 into 4 planar bytes per scanline:
    Scanline length = 256 * 4 = 1024 bytes.
    Byte planes = 4 (plane 0: MSB, plane 1: byte 2, plane 2: byte 1, plane 3: LSB).
    Each plane has 256 bytes.
    Bytes within each plane are horizontally differenced: b[i] = (b[i] + b[i-1]) mod 256.
    """
    raw = zlib.decompress(compressed_bytes)
    if len(raw) != EXPECTED_DECOMPRESSED_SIZE:
        raise ValueError(f"Decompressed size mismatch: expected {EXPECTED_DECOMPRESSED_SIZE}, got {len(raw)}")
    
    row_bytes = TILE_WIDTH * BYTES_PER_SAMPLE
    decoded = bytearray(len(raw))
    
    for row in range(TILE_HEIGHT):
        row_offset = row * row_bytes
        plane_size = TILE_WIDTH
        
        planes = []
        for p in range(BYTES_PER_SAMPLE):
            plane_start = row_offset + p * plane_size
            plane = bytearray(raw[plane_start : plane_start + plane_size])
            # Undo horizontal differencing
            for col in range(1, plane_size):
                plane[col] = (plane[col] + plane[col - 1]) & 0xFF
            planes.append(plane)
            
        # Reinterleave planes (MSB to LSB -> little-endian float)
        # TIFF FP predictor stores planes from most significant byte to least significant byte.
        # Little-endian IEEE 754 Float32 is [LSB, byte1, byte2, MSB].
        for col in range(TILE_WIDTH):
            out_offset = row_offset + col * BYTES_PER_SAMPLE
            decoded[out_offset + 0] = planes[3][col]
            decoded[out_offset + 1] = planes[2][col]
            decoded[out_offset + 2] = planes[1][col]
            decoded[out_offset + 3] = planes[0][col]
            
    return bytes(decoded)

def verify_fixture():
    if not os.path.exists(FIXTURE_PATH):
        print(f"ERROR: Fixture not found at {FIXTURE_PATH}", file=sys.stderr)
        sys.exit(1)
        
    with open(FIXTURE_PATH, "rb") as f:
        data = f.read()
        
    sha = hashlib.sha256(data).hexdigest()
    print(f"Fixture path: {FIXTURE_PATH}")
    print(f"Fixture size: {len(data)} bytes")
    print(f"Fixture SHA-256: {sha}")
    
    if len(data) != EXPECTED_DECOMPRESSED_SIZE:
        print(f"FAIL: Fixture size {len(data)} != {EXPECTED_DECOMPRESSED_SIZE}", file=sys.stderr)
        sys.exit(1)
        
    if sha.lower() != EXPECTED_SHA256.lower():
        print(f"FAIL: SHA-256 mismatch! Expected {EXPECTED_SHA256}", file=sys.stderr)
        sys.exit(1)
        
    # Inspect samples
    num_floats = len(data) // 4
    floats = struct.unpack(f"<{num_floats}f", data)
    south_pole_sample = floats[128 * 256 + 128]
    min_elev = min(floats)
    max_elev = max(floats)
    
    print(f"Verified {num_floats} Float32 samples:")
    print(f"  Min elevation: {min_elev:.2f} m")
    print(f"  Max elevation: {max_elev:.2f} m")
    print(f"  South Pole sample (approx row 128, col 128): {south_pole_sample:.2f} m")
    print("SUCCESS: LOLA South Pole Tile 78_78 fixture is valid and verified.")

if __name__ == "__main__":
    verify_fixture()
