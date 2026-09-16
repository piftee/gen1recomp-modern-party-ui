import hashlib
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('guard', Path(__file__).with_name('distribution_guard.py'))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

class DistributionTests(unittest.TestCase):
    def test_text_only_package(self):
        self.assertEqual(guard.check([('LICENSE', b'MIT'), ('main.lua', b'return function(mod) end')], {'assets': {}})[0], [])

    def test_unreviewed_media_and_disguised_binary(self):
        for name, data in [('art.png', b'anything'), ('hidden.lua', b'\x89PNG\r\n\x1a\n'), ('payload.txt', b'\0binary')]:
            self.assertIsNotNone(guard.inspect(name, data, {}), name)

    def test_encoded_media_in_text(self):
        for kind in [b'image/png', b'font/woff', b'audio/ogg']:
            payload = b'data:' + kind + b';base64,AAAA'
            self.assertIsNotNone(guard.inspect('style.css', payload, {}))

    def test_rom_header_without_extension(self):
        rom = bytearray(0x150)
        rom[0x104:0x134] = guard.GB_LOGO
        self.assertEqual(len(guard.GB_LOGO), 48)
        self.assertIn('ROM header', guard.inspect('renamed.dat', bytes(rom), {}))

    def test_nested_archives(self):
        self.assertIsNotNone(guard.inspect('hidden.lua', b'PK\x03\x04payload', {}))
        self.assertIsNotNone(guard.inspect('pack.zip', b'empty', {}))

    def test_grant_requires_exact_hash_and_notice(self):
        data = b'\x89PNG\r\n\x1a\nfixture'
        grant = {'sha256': hashlib.sha256(data).hexdigest(), 'license': 'CC0-1.0',
                 'source': 'original test fixture', 'notice': 'NOTICE.md'}
        policy = {'assets': {'icon.png': grant}}
        self.assertIsNone(guard.inspect('icon.png', data, policy['assets']))
        self.assertIsNotNone(guard.inspect('icon.png', data+b'changed', policy['assets']))
        entries = [('LICENSE', b'MIT'), ('icon.png', data)]
        self.assertTrue(guard.check(entries, policy)[0])
        self.assertFalse(guard.check(entries+[('NOTICE.md', b'CC0')], policy)[0])

    def test_import_and_screenshot_paths_cannot_be_approved(self):
        for name in ['screenshots/game.png', 'baseroms/game.txt', 'assets/generated/map.lua']:
            self.assertIsNotNone(guard.inspect(name, b'content', {}))

    def test_duplicate_and_traversal_paths(self):
        self.assertTrue(guard.check([('LICENSE', b'MIT'), ('LICENSE', b'MIT')], {'assets': {}})[0])
        for name in ['../outside.lua', '/absolute.lua', 'back\\slash.lua']:
            self.assertIsNotNone(guard.inspect(name, b'content', {}))

if __name__ == '__main__':
    unittest.main()
