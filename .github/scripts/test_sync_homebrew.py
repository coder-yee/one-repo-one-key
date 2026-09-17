"""Offline regression checks; never contacts GitHub or updates a repository."""
import base64
import hashlib
import io
import os
import tarfile
import unittest
import urllib.error
from unittest.mock import patch

import sync_homebrew as sync

OLD = 'a' * 64
NEW = 'b' * 64
FORMULA = f'''class Orok < Formula
  url "{sync.ARCHIVE_PREFIX}v0.1.1.tar.gz"
  sha256 "{OLD}"
  revision 2
  def install
    bin.install "orok.sh" => "orok"
  end
end
'''


class SyncTest(unittest.TestCase):
    def test_tag_push_creates_release_once(self):
        release = {'tag_name': 'v0.1.2', 'draft': False, 'prerelease': False,
                   'html_url': 'https://example.invalid/release'}
        missing = urllib.error.HTTPError('https://api.github.com', 404, 'Not Found', {}, None)
        with patch.object(sync, 'api') as api:
            api.side_effect = [missing, {'ref': 'refs/tags/v0.1.2'}, release]
            self.assertEqual(sync.ensure_release('v0.1.2', True, 'source-token'), release)
            self.assertIn('/git/ref/tags/v0.1.2', api.call_args_list[1].args[0])
            path, payload, token = api.call_args.args
            self.assertEqual(path, f'/repos/{sync.SOURCE}/releases')
            self.assertTrue(payload['generate_release_notes'])
            self.assertEqual(token, 'source-token')
            self.assertEqual(api.call_args.kwargs['method'], 'POST')
        with patch.object(sync, 'api', return_value=release) as api:
            sync.ensure_release('v0.1.2', True, 'source-token')
            self.assertEqual(api.call_count, 1)  # Retry reuses the published Release.

    def test_release_failures_do_not_publish(self):
        for create, code in [(True, 403), (False, 404)]:
            with patch.object(sync, 'api', side_effect=urllib.error.HTTPError(
                    'https://api.github.com', code, 'Failure', {}, None)) as api:
                with self.assertRaises(urllib.error.HTTPError):
                    sync.ensure_release('v0.1.2', create, 'source-token')
                self.assertEqual(api.call_count, 1)
        with patch.object(sync, 'api') as api:
            with self.assertRaises(ValueError):
                sync.ensure_release('v0.1.2', True)
            api.assert_not_called()
        missing = urllib.error.HTTPError('https://api.github.com', 404, 'Not Found', {}, None)
        with patch.object(sync, 'api', side_effect=[missing, missing]) as api:
            with self.assertRaises(urllib.error.HTTPError):
                sync.ensure_release('v0.1.2', True, 'source-token')
            self.assertEqual(api.call_count, 2)  # Missing tag never reaches POST.

    def test_upgrade_idempotency_and_downgrade(self):
        updated = sync.update_formula(FORMULA, 'v0.1.2', NEW)
        self.assertIn('v0.1.2.tar.gz', updated)
        self.assertIn(NEW, updated)
        self.assertNotIn('revision 2', updated)
        self.assertIn('bin.install "orok.sh" => "orok"', updated)
        self.assertEqual(sync.update_formula(updated, 'v0.1.2', NEW), updated)
        self.assertEqual(sync.update_formula(updated, 'v0.1.1', OLD), updated)

    def test_reject_invalid_inputs_and_changed_release(self):
        for tag in ['v1.2.3-rc1', 'v01.2.3', 'main', 'v1.2.3; echo secret']:
            with self.assertRaises(ValueError):
                sync.update_formula(FORMULA, tag, NEW)
        with self.assertRaises(ValueError):
            sync.update_formula(FORMULA, 'v0.1.1', NEW)
        with self.assertRaises(ValueError):
            sync.update_formula('unexpected formula', 'v0.1.2', NEW)

    def test_release_to_exact_file_update(self):
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode='w:gz') as archive:
            info = tarfile.TarInfo('one-repo-one-key-0.1.2/orok.sh')
            info.size = 1
            archive.addfile(info, io.BytesIO(b'\n'))
        content = buffer.getvalue()
        with patch.dict(os.environ, RELEASE_TAG='v0.1.2', HOMEBREW_TAP_TOKEN='test-token', CREATE_RELEASE='true', GH_TOKEN='source-token'), \
             patch.object(sync, 'request', return_value=content), \
             patch.object(sync, 'api') as api:
            api.side_effect = [
                urllib.error.HTTPError('https://api.github.com', 404, 'Not Found', {}, None),
                {'ref': 'refs/tags/v0.1.2'},
                {'tag_name': 'v0.1.2', 'draft': False, 'prerelease': False, 'html_url': 'https://example.invalid/release'},
                {'content': base64.b64encode(FORMULA.encode()).decode(), 'sha': 'old-blob'},
                {'commit': {'html_url': 'https://example.invalid/commit'}},
            ]
            sync.main()
            path, payload, token = api.call_args.args
            self.assertEqual(path, sync.FORMULA)
            self.assertEqual((payload['branch'], payload['sha'], token), ('main', 'old-blob', 'test-token'))
            self.assertIn(hashlib.sha256(content).hexdigest(), base64.b64decode(payload['content']).decode())

    def test_prerelease_never_downloads_or_writes(self):
        with patch.dict(os.environ, RELEASE_TAG='v0.1.2', HOMEBREW_TAP_TOKEN='test-token'), \
             patch.object(sync, 'api', return_value={'tag_name': 'v0.1.2', 'draft': False, 'prerelease': True}) as api, \
             patch.object(sync, 'request') as download:
            with self.assertRaises(ValueError):
                sync.main()
            self.assertEqual(api.call_count, 1)
            download.assert_not_called()


if __name__ == '__main__':
    unittest.main()
