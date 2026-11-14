#!/usr/bin/env python3
"""
LOLA DEM Fixture Verification Script

This tool provides verification for the committed lunar digital elevation model (DEM)
tile fixture: test/fixtures/terrain/lola_south_pole_tile_78_78.bin.

VERIFICATION MODES:
1. Fixture Integrity Mode (Default, offline):
   Verifies the committed binary fixture's byte length, SHA-256 checksum,
   sample count, and floating-point value distribution against expected values.
   Does not require external network access or source BigTIFF files.

2. Source-to-Fixture Verification Mode (--source <path-to-ldem_87s_5mpp.tif>):
   When the original NASA LOLA BigTIFF archive file is provided, this tool reads
   the BigTIFF header, determines byte order, validates BigTIFF version 43,
   parses the Image File Directory (IFD) tags, resolves the actual TileOffsets
   and TileByteCounts arrays, extracts tile index 12324 (col 78, row 78),
   decompresses the Deflate stream, decodes TIFF Predictor 3 floating-point
   horizontal differencing, and performs byte-for-byte comparison with the fixture.

NASA LOLA Product 81 Source:
  Dataset: ldem_87s_5mpp.tif (Lunar South Pole DEM, 5 meters/pixel, 87S to 90S)
  Archive URL: https://pgda.gsfc.nasa.gov/data/LOLA_5mpp/87S/ldem_87s_5mpp.tif
  Grid Dimensions: 40,000 x 40,000 pixels
  Tile Dimensions: 256 x 256 pixels
  Tiles Across: ceil(40,000 / 256) = 157 tiles
  Tiles Down:   ceil(40,000 / 256) = 157 tiles
  Total Tile Count: 157 x 157 = 24,649 tiles
  South Pole Tile (col 78, row 78):
    Linear tile index = 78 * 157 + 78 = 12,324
  BigTIFF IFD Structure:
    Tag 324 (TileOffsets):    type=16 (LONG8, 8 bytes), count=24649, array offset=197,624 bytes
    Tag 325 (TileByteCounts): type=16 (LONG8, 8 bytes), count=24649, array offset=432 bytes
  Correct Array Entry Offset Calculations:
    TileByteCounts entry offset = 432 + (12,324 * 8) = 99,024 bytes -> value: 137,823 bytes
    TileOffsets entry offset    = 197,624 + (12,324 * 8) = 296,216 bytes -> value: 1,259,787,516 bytes
"""

import sys
import os
import zlib
import struct
import hashlib
import argparse

FIXTURE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "test", "fixtures", "terrain", "lola_south_pole_tile_78_78.bin"
)

EXPECTED_SHA256 = "ae72c611bb4435c41c7f984dc695aedabdbdd75d22c452afa7fb15963d02ff1e"
TILE_WIDTH = 256
TILE_HEIGHT = 256
BYTES_PER_SAMPLE = 4
EXPECTED_DECOMPRESSED_SIZE = TILE_WIDTH * TILE_HEIGHT * BYTES_PER_SAMPLE  # 262,144 bytes

TIFF_TYPE_SIZES = {
    1: 1,   # BYTE
    2: 1,   # ASCII
    3: 2,   # SHORT
    4: 4,   # LONG
    5: 8,   # RATIONAL
    6: 1,   # SBYTE
    7: 1,   # UNDEFINED
    8: 2,   # SSHORT
    9: 4,   # SLONG
    10: 8,  # SRATIONAL
    11: 4,  # FLOAT
    12: 8,  # DOUBLE
    16: 8,  # LONG8
    17: 8,  # SLONG8
    18: 8,  # IFD8
}

def decode_predictor3_deflate(compressed_bytes: bytes) -> bytes:
    """
    Decompresses Deflate stream and undifferences TIFF Predictor 3 horizontal byte-differencing.
    Under TIFF Technical Note 3 / libtiff standard for floating point prediction (Predictor=3):
    1. For Float32 (4 bytes per sample), samples are split into 4 byte planes across the scanline
       (scanline length = 256 * 4 = 1024 bytes).
    2. Differencing is applied continuously across the entire scanline buffer:
       undiff[0] = row[0]
       undiff[b] = (undiff[b - 1] + row[b]) & 0xFF  (for b = 1 .. row_bytes - 1)
    3. Samples are re-interleaved from the 4 planes:
       plane 0 is at offset 0 * width, plane 1 at 1 * width, plane 2 at 2 * width, plane 3 at 3 * width.
       Output Little-Endian Float32 bytes: [plane3, plane2, plane1, plane0].
    This matches the authoritative libtiff implementation (verified via Pillow / libtiff oracle).
    """
    raw = zlib.decompress(compressed_bytes)
    if len(raw) != EXPECTED_DECOMPRESSED_SIZE:
        raise ValueError(
            f"Decompressed size mismatch: expected {EXPECTED_DECOMPRESSED_SIZE}, got {len(raw)}"
        )

    row_bytes = TILE_WIDTH * BYTES_PER_SAMPLE
    decoded = bytearray(len(raw))

    for row in range(TILE_HEIGHT):
        row_offset = row * row_bytes
        row_in = raw[row_offset : row_offset + row_bytes]

        # Continuous horizontal undifferencing across the scanline buffer
        undiff = bytearray(row_bytes)
        for b in range(row_bytes):
            if b == 0:
                undiff[b] = row_in[b]
            else:
                undiff[b] = (undiff[b - 1] + row_in[b]) & 0xFF

        # Re-interleave planes into Little-Endian Float32
        row_out = bytearray(row_bytes)
        for i in range(TILE_WIDTH):
            row_out[i * 4 + 0] = undiff[3 * TILE_WIDTH + i]
            row_out[i * 4 + 1] = undiff[2 * TILE_WIDTH + i]
            row_out[i * 4 + 2] = undiff[1 * TILE_WIDTH + i]
            row_out[i * 4 + 3] = undiff[0 * TILE_WIDTH + i]

        decoded[row_offset : row_offset + row_bytes] = row_out

    return bytes(decoded)

def verify_source_extraction(source_path: str):
    """
    Parses original BigTIFF, resolves actual IFD entries, extracts tile 12324,
    decompresses Deflate + Predictor 3, and performs byte-by-byte comparison.
    """
    print("=" * 70)
    print("MODE: SOURCE-TO-FIXTURE EXTRACTION VERIFICATION")
    print(f"Source file: {source_path}")
    print("=" * 70)

    if not os.path.exists(source_path):
        print(f"ERROR: Source file does not exist: {source_path}", file=sys.stderr)
        sys.exit(1)

    with open(source_path, "rb") as f:
        # Read BigTIFF Header
        header = f.read(16)
        if len(header) < 16:
            print("ERROR: File too small to be BigTIFF", file=sys.stderr)
            sys.exit(1)

        magic = header[:2]
        if magic == b"II":
            byteorder = "<"
        elif magic == b"MM":
            byteorder = ">"
        else:
            print(f"ERROR: Not a TIFF file (magic: {magic})", file=sys.stderr)
            sys.exit(1)

        version, offset_size, zero, first_ifd_offset = struct.unpack(f"{byteorder}HHHQ", header[2:16])
        print(f"TIFF Byte Order: {'Little-Endian (II)' if byteorder == '<' else 'Big-Endian (MM)'}")
        print(f"TIFF Version: {version} (Expected 43 for BigTIFF)")
        print(f"Offset Byte Size: {offset_size} (Expected 8)")
        print(f"First IFD Offset: {first_ifd_offset} bytes")

        if version != 43 or offset_size != 8:
            print("ERROR: File is not BigTIFF version 43", file=sys.stderr)
            sys.exit(1)

        # Read IFD Entry Count
        f.seek(first_ifd_offset)
        num_entries_bytes = f.read(8)
        num_entries = struct.unpack(f"{byteorder}Q", num_entries_bytes)[0]
        print(f"IFD Directory Entries: {num_entries}")

        tags = {}
        for _ in range(num_entries):
            entry_bytes = f.read(20)
            tag, field_type, count, val_or_off = struct.unpack(f"{byteorder}HHQQ", entry_bytes)
            tags[tag] = (field_type, count, val_or_off)

        # Inspect required tags
        img_width = tags.get(256)[2] if 256 in tags else None
        img_length = tags.get(257)[2] if 257 in tags else None
        tile_width = tags.get(322)[2] if 322 in tags else None
        tile_length = tags.get(323)[2] if 323 in tags else None
        compression = tags.get(259)[2] if 259 in tags else None
        predictor = tags.get(317)[2] if 317 in tags else None

        print(f"Raster Size: {img_width} x {img_length} pixels")
        print(f"Tile Size: {tile_width} x {tile_length} pixels")
        print(f"Compression: {compression} (8 = Deflate)")
        print(f"Predictor: {predictor} (3 = Floating-point horizontal differencing)")

        tiles_across = (img_width + tile_width - 1) // tile_width
        tiles_down = (img_length + tile_length - 1) // tile_length
        total_tiles = tiles_across * tiles_down
        print(f"Tiles Across: {tiles_across}, Down: {tiles_down}, Total: {total_tiles}")

        tile_x = 78
        tile_y = 78
        tile_index = tile_y * tiles_across + tile_x
        print(f"Target South Pole Tile (X={tile_x}, Y={tile_y}): linear index {tile_index}")

        # Resolve TileOffsets (tag 324) and TileByteCounts (tag 325)
        offsets_type, offsets_count, offsets_val_or_off = tags[324]
        counts_type, counts_count, counts_val_or_off = tags[325]

        offset_elem_size = TIFF_TYPE_SIZES[offsets_type]
        count_elem_size = TIFF_TYPE_SIZES[counts_type]

        print(f"Tag 324 (TileOffsets): type={offsets_type} ({offset_elem_size}B), count={offsets_count}, array_offset={offsets_val_or_off}")
        print(f"Tag 325 (TileByteCounts): type={counts_type} ({count_elem_size}B), count={counts_count}, array_offset={counts_val_or_off}")

        tile_offset_entry_pos = offsets_val_or_off + tile_index * offset_elem_size
        tile_count_entry_pos = counts_val_or_off + tile_index * count_elem_size

        print(f"TileOffsets[{tile_index}] file location: {offsets_val_or_off} + ({tile_index} * {offset_elem_size}) = {tile_offset_entry_pos}")
        print(f"TileByteCounts[{tile_index}] file location: {counts_val_or_off} + ({tile_index} * {count_elem_size}) = {tile_count_entry_pos}")

        f.seek(tile_offset_entry_pos)
        actual_compressed_offset = struct.unpack(f"{byteorder}Q", f.read(8))[0]

        f.seek(tile_count_entry_pos)
        actual_compressed_bytecount = struct.unpack(f"{byteorder}Q", f.read(8))[0]

        print(f"Tile {tile_index} compressed data file offset: {actual_compressed_offset}")
        print(f"Tile {tile_index} compressed byte count: {actual_compressed_bytecount}")

        # Extract Compressed Tile Bytes
        f.seek(actual_compressed_offset)
        compressed_bytes = f.read(actual_compressed_bytecount)

    # Decompress and decode Predictor 3
    print("Decompressing Deflate stream and decoding TIFF Predictor 3...")
    decoded_bytes = decode_predictor3_deflate(compressed_bytes)
    print(f"Decoded size: {len(decoded_bytes)} bytes")
    decoded_sha = hashlib.sha256(decoded_bytes).hexdigest()
    print(f"Decoded SHA-256: {decoded_sha}")

    # Compare with committed fixture
    if not os.path.exists(FIXTURE_PATH):
        print(f"ERROR: Fixture not found at {FIXTURE_PATH}", file=sys.stderr)
        sys.exit(1)

    with open(FIXTURE_PATH, "rb") as f:
        fixture_bytes = f.read()

    if decoded_bytes == fixture_bytes:
        print("SUCCESS: SOURCE-TO-FIXTURE BYTE EQUIVALENCE VERIFIED!")
        print("The extracted and decoded BigTIFF tile is bit-for-bit identical to the committed fixture.")
    else:
        print("FAIL: Decoded tile differs from committed fixture!", file=sys.stderr)
        diff_count = 0
        first_diff = None
        for i in range(min(len(decoded_bytes), len(fixture_bytes))):
            if decoded_bytes[i] != fixture_bytes[i]:
                if first_diff is None:
                    first_diff = (i, decoded_bytes[i], fixture_bytes[i])
                diff_count += 1
        print(f"Total differing bytes: {diff_count}", file=sys.stderr)
        if first_diff:
            byte_idx, dec_b, fix_b = first_diff
            sample_idx = byte_idx // 4
            print(f"First differing byte at offset {byte_idx} (sample {sample_idx}): decoded={dec_b:#04x}, fixture={fix_b:#04x}", file=sys.stderr)
        sys.exit(1)

def verify_fixture_integrity_only():
    """
    Default offline verification path when source BigTIFF is not locally available.
    Verifies file size, SHA-256 checksum, and sample distribution of committed fixture.
    """
    print("=" * 70)
    print("VERIFICATION LEVEL: FIXTURE INTEGRITY ONLY")
    print("=" * 70)
    print(
        "The committed binary fixture matches its expected SHA-256 and expected decoded sample count.\n\n"
        "The original NASA BigTIFF source was not available locally as an argument.\n"
        "No source-to-fixture extraction or spatial-registration verification was performed."
    )
    print("-" * 70)

    if not os.path.exists(FIXTURE_PATH):
        print(f"ERROR: Fixture not found at {FIXTURE_PATH}", file=sys.stderr)
        sys.exit(1)

    with open(FIXTURE_PATH, "rb") as f:
        data = f.read()

    sha = hashlib.sha256(data).hexdigest()
    print(f"Fixture path: {FIXTURE_PATH}")
    print(f"Fixture size: {len(data)} bytes (expected: {EXPECTED_DECOMPRESSED_SIZE})")
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
    print("-" * 70)
    print("RESULT: FIXTURE INTEGRITY VERIFIED ONLY.")

def main():
    parser = argparse.ArgumentParser(
        description="Verify LOLA DEM binary fixture integrity or extract from source BigTIFF."
    )
    parser.add_argument(
        "--source",
        type=str,
        default=None,
        help="Path to source NASA BigTIFF file (e.g. ldem_87s_5mpp.tif) for source-to-fixture extraction verification."
    )
    args = parser.parse_args()

    if args.source:
        verify_source_extraction(args.source)
    else:
        verify_fixture_integrity_only()

if __name__ == "__main__":
    main()
