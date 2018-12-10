from collections import defaultdict
import re
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
        self._ref_cache = {}

    @property
    def target_root(self):
        return self.config.get('target', self.name)

    @property
    def branches(self):
        return self.config["branches"]

    def ref(self, branch_name):
        # fall back to local branch
        self._ref_cache[branch_name] = branch_name
        # but prefer remote state
        for remote in self.git.remotes:
            ref = '{}/{}'.format(remote.name, branch_name)
            if self.git.lookup_branch(ref, pygit2.GIT_BRANCH_REMOTE):
                self._ref_cache[branch_name] = ref
                break
        return self._ref_cache[branch_name]


CHANNEL_REVS = re.compile(
    "^X-Channel-(?:Converted-)?Revision: "
    "\[(?P<branch>.+?)\] (?P<repo>[^@\n]*?)@(?P<rev>[a-f0-9]{40})$",
    re.M,
)


class TargetRepository(Repository):
    def __init__(self, path, branch):
        super().__init__(path)
        self.target_branch = branch

    def converted_revs(self):
        branch = self.git.lookup_branch(self.target_branch).target
        walker = self.git.walk(branch, pygit2.GIT_SORT_TOPOLOGICAL)
        for commit in walker:
            revs = defaultdict(dict)
            for m in CHANNEL_REVS.finditer(commit.message):
                revs[m.group("repo")][m.group("branch")] = m.group("rev")
            if revs:
                yield revs

    def known_revs(self):
        revs = set()
        for rev in self.converted_revs():
            for branch_revs in rev.values():
                revs.update(branch_revs.values())
        return revs
