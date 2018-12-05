import subprocess
import pygit2


class Repository(object):
    def __init__(self, path):
        self.path = path
        self._git = None

    def __getitem__(self, key):
        return self.git[key]

    @property
    def git(self):
        if self._git is None:
            self._git = pygit2.Repository(self.path)
        return self._git

    def pull(self):
        cmd = ["git", "-C", self.path, "pull", "-q"]
        subprocess.run(cmd)


class SourceRepository(Repository):
    def __init__(self, config, root=None):
        self.name = path = "{}/{}".format(config["org"], config["name"])
        if root is not None:
            path = "{}/{}".format(root, path)
        super().__init__(path)
        self.config = config

    @property
    def target_root(self):
        return self.name

    @property
    def branches(self):
        return self.config["branches"]
