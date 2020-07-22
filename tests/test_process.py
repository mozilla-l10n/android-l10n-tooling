from unittest import TestCase
from unittest import mock
from mozxchannel.git import process
from compare_locales.paths import TOMLParser


class TestCommitsGraph(TestCase):
    @mock.patch('mozxchannel.git.process.glob')
    @mock.patch(
        "mozxchannel.git.repository.TargetRepository.__init__",
        return_value=None,
    )
    @mock.patch('os.path.isdir')
    def test_references_file(self, is_dir, target_repo_mock, glob_mock):
        g = process.CommitsGraph("target_dir", "master", None)
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
    @mock.patch(
        "mozxchannel.git.repository.TargetRepository.__init__",
        return_value=None,
    )
    @mock.patch('os.path.isdir')
    def test_references_wildcard(self, is_dir, target_repo_mock, glob_mock):
        g = process.CommitsGraph("target_dir", "master", None)
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
