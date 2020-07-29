import json
import os
import subprocess
import pygit2
import pytoml as toml


NULL_REV = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"  # noqa


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
        if os.path.isdir(self.path):
            cmd = ["git", "-C", self.path, "pull", "-q"]
        else:
            orgdir = os.path.dirname(self.path)
            if not os.path.isdir(orgdir):
                os.makedirs(orgdir)
            cmd = [
                "git",
                "-C", orgdir,
                "clone", "-q",
                os.environ.get(
                    "X_CHANNEL_UPSTREAM",
                    "https://github.com"
                ) + "/" + self.path
            ]
        subprocess.run(cmd)

    def ensure_branch(self, branch_name):
        if self.git.lookup_branch(branch_name) is not None:
            return
        # Expected branch doesn't exist, branch HEAD
        self.git.branches.local.create(branch_name, self[self.git.head.target])

    def checkout(self, branch_name):
        b = self.git.lookup_branch(branch_name)
        self.git.checkout(b.name)


class SourceRepository(Repository):
    def __init__(self, config, root=None):
        self.name = path = "{}/{}".format(config["org"], config["name"])
        self.branch = config["branch"]
        if root is not None:
            path = "{}/{}".format(root, path)
        super().__init__(path)
        self.config = config
        self._ref_cache = {}

    @property
    def target_root(self):
        return self.config.get('target', self.name)

    def branches(self, rev=None):
        if rev is None:
            rev = self.lookup_branch(self.branch).target
        tree = self[rev].tree
        if 'l10n.toml' not in tree:
            return [self.branch]
        toml_data = self[tree['l10n.toml'].id].data
        config = toml.loads(toml_data)
        return config.get("branches", [self.branch])

    def lookup_branch(self, branch_name):
        # prefer remote state
        for remote in self.git.remotes:
            ref = '{}/{}'.format(remote.name, branch_name)
            branch = self.git.lookup_branch(ref, pygit2.GIT_BRANCH_REMOTE)
            if branch:
                return branch
        # but fall back to local branch
        return self.git.lookup_branch(branch_name)

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


class TargetRepository(Repository):
    def __init__(self, path, branch):
        super().__init__(path)
        self.target_branch = branch
        self.ensure_branch(branch)
        self.checkout(branch)

    def converted_revs(self):
        branch = self.git.lookup_branch(self.target_branch).target
        tree = self[branch].tree
        if '_meta' not in tree:
            return {}
        tree = self[tree['_meta'].id]
        revs = {}
        for treeitem in tree:
            data = json.loads(self[treeitem.id].data)
            revs[data['name']] = data['revs']
        return revs

    def known_revs(self):
        revs = set()
        for branch_revs in self.converted_revs().values():
            revs.update(branch_revs.values())
        return revs
