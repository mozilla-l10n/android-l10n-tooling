from unittest import TestCase
import os
import shutil
import subprocess
import tempfile
from mozxchannel.git import repository


class TestRepository(TestCase):
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

    def test_ensure_master_branch(self):
        repo = repository.Repository(self.workdir)
        repo.ensure_branch("master")

    def test_ensure_new_branch(self):
        repo = repository.Repository(self.workdir)
        repo.ensure_branch("new")
        proc = subprocess.run(
            ["git", "show-branch", "new"],
            cwd=self.workdir,
            capture_output=True
        )
        self.assertIn(b'[new]', proc.stdout)
        self.assertIn(b' c2', proc.stdout)
        repo.checkout("new")
