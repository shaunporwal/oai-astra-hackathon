import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from eye_vision.config import configure_api_key


class ConfigTests(unittest.TestCase):
    def test_alias_is_loaded_without_expansion_or_other_variables(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {}, clear=True):
            path = Path(directory) / '.env'
            path.write_text('oai_api_key="test-${UNCHANGED}"\nUNRELATED=value\n')
            self.assertTrue(configure_api_key(path))
            self.assertEqual(os.environ['OPENAI_API_KEY'], 'test-${UNCHANGED}')
            self.assertNotIn('UNRELATED', os.environ)

    def test_shell_precedence_including_explicit_disable(self):
        for value in ('shell-key', ''):
            with self.subTest(value=value), patch.dict(os.environ, {'OPENAI_API_KEY': value}, clear=True):
                self.assertEqual(configure_api_key('/nonexistent/.env'), bool(value))
                self.assertEqual(os.environ['OPENAI_API_KEY'], value)

    def test_missing_file_leaves_key_unconfigured(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertFalse(configure_api_key('/nonexistent/.env'))
            self.assertNotIn('OPENAI_API_KEY', os.environ)
