"""Validate distributable artwork without a macOS runtime or third-party libraries."""
import json
from pathlib import Path
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]


def png_dimensions(path):
    raw = path.read_bytes()
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise AssertionError(f'Not a PNG: {path}')
    offset, dimensions, ended = 8, None, False
    while offset < len(raw):
        size = struct.unpack('>I', raw[offset:offset + 4])[0]
        kind = raw[offset + 4:offset + 8]
        data = raw[offset + 8:offset + 8 + size]
        crc = struct.unpack('>I', raw[offset + 8 + size:offset + 12 + size])[0]
        if zlib.crc32(kind + data) & 0xffffffff != crc:
            raise AssertionError(f'Corrupt PNG chunk: {path}')
        if kind == b'IHDR':
            dimensions = struct.unpack('>II', data[:8])
        if kind == b'IEND':
            ended = True
        offset += size + 12
    if not ended or offset != len(raw):
        raise AssertionError(f'Truncated PNG: {path}')
    return dimensions


def image_dimensions(path):
    if path.suffix.lower() == '.png':
        return png_dimensions(path)
    raw = path.read_bytes()
    if raw[:2] != b'\xff\xd8':
        raise AssertionError(f'Not a supported preview: {path}')
    offset = 2
    while offset < len(raw):
        if raw[offset] != 0xff:
            raise AssertionError(f'Invalid JPEG marker: {path}')
        while raw[offset] == 0xff:
            offset += 1
        marker = raw[offset]
        offset += 1
        length = struct.unpack('>H', raw[offset:offset + 2])[0]
        if marker in (0xc0, 0xc1, 0xc2):
            height, width = struct.unpack('>HH', raw[offset + 3:offset + 7])
            return width, height
        offset += length
    raise AssertionError(f'No JPEG frame: {path}')


class AssetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT / 'assets/manifest.json').read_text())

    def asset(self, relative):
        path = (ROOT / relative).resolve()
        self.assertTrue(path.is_relative_to(ROOT / 'assets'))
        self.assertTrue(path.is_file(), str(path))
        return path

    def test_six_full_resolution_wallpapers_and_previews(self):
        wallpapers = self.manifest['wallpapers']
        self.assertEqual(len(wallpapers), 6)
        self.assertEqual({w['id'] for w in wallpapers}, {
            f'{design}-{variant}'
            for design in ('aero-sky', 'crystal-ocean', 'aero-meadow')
            for variant in ('light', 'dark')
        })
        for wall in wallpapers:
            with self.subTest(wallpaper=wall['id']):
                width, height = png_dimensions(self.asset(wall['file']))
                self.assertEqual((width, height), (wall['width'], wall['height']))
                self.assertGreaterEqual(width, 2560)
                self.assertGreaterEqual(height, 1600)
                preview = image_dimensions(self.asset(wall['thumbnail']))
                self.assertLess(preview[0], width)

    def test_icon_pack_is_complete_and_icns_chunks_are_valid(self):
        icons = self.manifest['icons']
        self.assertEqual(len(icons), 17)
        self.assertEqual(len({icon['id'] for icon in icons}), 17)
        for icon in icons:
            with self.subTest(icon=icon['id']):
                width, height = png_dimensions(self.asset(icon['file']))
                self.assertEqual(width, height)
                self.assertGreaterEqual(width, 128)
                raw = self.asset(icon['icns']).read_bytes()
                self.assertEqual(raw[:4], b'icns')
                self.assertEqual(struct.unpack('>I', raw[4:8])[0], len(raw))
                offset, count = 8, 0
                while offset < len(raw):
                    length = struct.unpack('>I', raw[offset + 4:offset + 8])[0]
                    self.assertGreaterEqual(length, 8)
                    self.assertLessEqual(offset + length, len(raw))
                    offset += length
                    count += 1
                self.assertEqual(offset, len(raw))
                self.assertGreaterEqual(count, 3)

    def test_cursor_scales_and_hotspots(self):
        cursors = self.manifest['cursors']
        self.assertEqual(len(cursors), 10)
        for cursor in cursors:
            with self.subTest(cursor=cursor['id']):
                self.assertEqual(png_dimensions(self.asset(cursor['file'])), (64, 64))
                self.assertEqual(png_dimensions(self.asset(cursor['retina'])), (128, 128))
                self.assertEqual(len(cursor['hotspot']), 2)
                for coordinate in cursor['hotspot']:
                    self.assertGreaterEqual(coordinate, 0)
                    self.assertLess(coordinate, 32)


if __name__ == '__main__':
    unittest.main()
