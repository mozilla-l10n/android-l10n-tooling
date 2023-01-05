from unittest import TestCase
from unittest import mock
from mozxchannel.git import process
from compare_locales.paths import TOMLParser


class TestCommitsGraph(TestCase):
    @mock.patch('mozxchannel.git.process.glob')
    @mock.patch('os.path.isdir')
    def test_references_file(self, is_dir, glob_mock):
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
        is_dir.side_effect = lambda p: not p.endswith("fixed/file.ftl")
        glob_mock.side_effect = Exception("not called")
