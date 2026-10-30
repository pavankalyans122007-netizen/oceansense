"""Exercise user-visible CLI behavior in a disposable state directory."""
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CLITests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='aero-cli-')
        self.addCleanup(self.temporary.cleanup)
        self.state = Path(self.temporary.name) / 'state'
        self.environment = dict(os.environ, AERO_BLUE_STATE=str(self.state))

    def invoke(self, *arguments, success=True):
        result = subprocess.run(
            [sys.executable, str(ROOT / 'scripts/aero.py'), *arguments],
            env=self.environment, capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return json.loads(result.stdout if success else result.stderr)

    def test_read_only_detection_and_defaults_do_not_write_user_state(self):
        report = self.invoke('check')
        self.assertEqual(report['platform'], platform.system())
        self.assertFalse(report['changesMade'])
        settings = self.invoke('settings', 'get')
        self.assertFalse(settings['enabled'])
        self.assertEqual(settings['schemaVersion'], 1)
        self.assertFalse(self.state.exists())

    def test_settings_persist_across_processes_and_invalid_updates_are_atomic(self):
        self.invoke('settings', 'set', '{"clock24h":false,"dock":{"tilesize":60}}')
        before = self.invoke('settings', 'get')
        self.assertFalse(before['clock24h'])
        self.assertEqual(before['dock']['tilesize'], 60)
        self.invoke('settings', 'set', '{"dock":{"tilesize":-5}}', success=False)
        self.assertEqual(self.invoke('settings', 'get'), before)
        self.assertIn('magnification', before['dock'])

    def test_tasks_are_literal_persistent_text_and_focus_survives_restarts(self):
        task_text = "Write 'blue' notes; $(touch MUST_NOT_EXIST) `date` & keep \"quotes\""
        data = self.invoke('productivity', 'add', task_text)
        task = data['tasks'][0]
        self.assertEqual(task['text'], task_text)
        self.invoke('productivity', 'toggle', task['id'])
        self.assertTrue(self.invoke('productivity', 'get')['tasks'][0]['completed'])
        started = self.invoke('productivity', 'focus', '25')['focus']
        self.assertIsInstance(started['endsAt'], int)
        self.assertEqual(self.invoke('productivity', 'get')['focus'], started)
        self.invoke('productivity', 'stop')
        self.assertIsNone(self.invoke('productivity', 'get')['focus']['endsAt'])
        self.invoke('productivity', 'remove', task['id'])
        self.assertEqual(self.invoke('productivity', 'get')['tasks'], [])

    def test_weather_requires_an_explicit_location(self):
        weather = self.invoke('weather')
        self.assertFalse(weather['available'])
        self.assertNotIn('temperature', weather)
        self.assertTrue(weather['error'])

    @unittest.skipIf(platform.system() == 'Darwin', 'This check specifically verifies the Linux guard')
    def test_native_mutations_refuse_linux_even_with_confirmation(self):
        for command in ('install', 'apply', 'restore', 'uninstall'):
            with self.subTest(command=command):
                error = self.invoke(command, '--yes', success=False)
                self.assertIn('requires macOS', error['error'])
        self.assertFalse(self.state.exists())

    def test_noninteractive_installer_requires_explicit_authorization(self):
        result = subprocess.run(
            ['bash', str(ROOT / 'scripts/install.sh')], env=self.environment,
            stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=10,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('No changes made', result.stderr)
        self.assertFalse(self.state.exists())


if __name__ == '__main__':
    unittest.main()
