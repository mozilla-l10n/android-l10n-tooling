from unittest import TestCase
from unittest import mock
import os
import shutil
import subprocess
import tempfile
from mozxchannel.git import process
from compare_locales.paths import TOMLParser


class TestCommitsGraph(TestCase):
    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        env = {
            "GIT_AUTHOR_NAME": "Jane Doe",
            "GIT_AUTHOR_EMAIL": "Jane@example.tld",
            "GIT_COMMITTER_NAME": "Jane Doe",
            "GIT_COMMITTER_EMAIL": "Jane@example.tld",
        }
        for cmd in [
            ["git", "init"],
            "some content",
            ["git", "add", "file"],
            ["git", "commit", "-m", "c1"],
            "more content",
            ["git", "commit", "-am", "c2"],
        ]:
            if isinstance(cmd, str):
                with open(os.path.join(self.workdir, "file"), "w") as fh:
                    fh.write(cmd + "\n")
            else:
                subprocess.run(
                    cmd,
                    cwd=self.workdir, capture_output=True, env=env
                )

    def tearDown(self):
        shutil.rmtree(self.workdir)
        self.workdir = None

    @mock.patch('mozxchannel.git.process.glob')
    @mock.patch('os.path.isdir')
    def test_references_file(self, is_dir, glob_mock):
        g = process.CommitsGraph(self.workdir, "master", None)
        parser = TOMLParser()

        def mock_load(ctx):
            ctx.data = {
                "locales": [],
                "paths": [
                    {
                        "reference": "some/fixed/file.ftl",
                        "l10n": "{android_locale}/file.ftl",
                    },
                ],
            }

        parser.load = mock.MagicMock(side_effect=mock_load)
        pc = parser.parse("a/basedir/l10n.toml")
        is_dir.side_effect = lambda p: not p.endswith("fixed/file.ftl")
        glob_mock.side_effect = Exception("not called")
        self.assertListEqual(
            g.references(pc, "a/basedir"),
            ["l10n.toml", "some/fixed/file.ftl"]
        )

    @mock.patch('mozxchannel.git.process.glob')
    @mock.patch('os.path.isdir')
    def test_references_wildcard(self, is_dir, glob_mock):
        g = process.CommitsGraph(self.workdir, "master", None)
        parser = TOMLParser()

        def mock_load(ctx):
            ctx.data = {
                "locales": [],
                "paths": [
                    {
                        "reference": "some/**/file.ftl",
                        "l10n": "**/{android_locale}/file.ftl",
                    },
                ],
            }

        parser.load = mock.MagicMock(side_effect=mock_load)
        pc = parser.parse("a/basedir/l10n.toml")
        is_dir.side_effect = lambda p: not p.endswith("fixed/file.ftl")
        glob_mock.return_value = [
            pc.root + f
            for f in [
                "/some/other/content",
                "/some/other/file.ftl",
                "/some/second/deep/file.ftl",
            ]
        ]
        self.assertListEqual(
            g.references(pc, "a/basedir"),
            ["l10n.toml", "some/other/file.ftl", "some/second/deep/file.ftl"]
        )
