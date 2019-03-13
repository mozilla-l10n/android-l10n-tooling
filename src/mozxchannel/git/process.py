import argparse
from collections import defaultdict
import json
import os
import subprocess

import pytoml as toml
from compare_locales.paths import TOMLParser
from compare_locales import mozpath
from compare_locales.merge import merge_channels, MergeNotSupportedError
from mozxchannel import walker
from mozxchannel.git.repository import (
    SourceRepository,
    TargetRepository,
)


def handle(target, target_branch, repos_to_iterate, pull=False):
    graph = CommitsGraph(target, target_branch)
    graph.loadConfigs()
    if pull:
        graph.pull()
    graph.loadRevs()
    graph.gather(repos_to_iterate)
    return graph


class CommitsGraph:
    def __init__(self, target, branch, source=None):
        self.config = None
        self.repos = None
        self.source = source
        self.repos_for_hash = defaultdict(list)
        self.hashes_for_repo = defaultdict(set)
        self.paths_for_repos = {}
        self.branches = {}
        self.commit_dates = {}
        self.forks = defaultdict(list)
        self.parents = defaultdict(set)
        self.children = defaultdict(set)
        self.target = TargetRepository(target, branch)
        self.target_branch = branch
        self.revs = {}

    def loadRevs(self):
        revs = self.target.converted_revs()
        for repo in self.repos:
            repo_name = repo.name
            self.revs[repo_name] = {}
            if repo_name not in revs:
                continue
            for n, branch in enumerate(repo.branches()):
                if branch in revs[repo_name]:
                    self.revs[repo_name][branch] = revs[repo_name][branch]

    @property
    def roots(self):
        roots = list(set(self.children) - set(self.parents))
        for commits in self.hashes_for_repo.values():
            # only one commit, we don't have parents or children,
            # but something to do
            roots += commits
        return roots

    def loadConfigs(self):
        config_path = os.path.join(self.target.git.workdir, "config.toml")
        repo_configs = toml.load(open(config_path))["repo"]
        self.repos = [
            SourceRepository(config, root=self.source)
            for config in repo_configs
        ]

    def pull(self):
        for repo in self.repos:
            repo.pull()

    def gather(self, repos_to_iterate):
        for repo in self.repos:
            process_revisions = not (
                repos_to_iterate and repo.name not in repos_to_iterate
            )
            self.gather_repo(repo, process_revisions)
        # We have added parents outside of commit range.
        # Find and remove them.
        for commit in list(self.children.keys()):
            if commit not in self.commit_dates:
                children = self.children.pop(commit)
                for child in children:
                    self.parents[child].remove(commit)

    def gather_repo(self, repo, process_revisions):
        basepath = repo.path
        pc = TOMLParser().parse(mozpath.join(basepath, "l10n.toml"))
        paths = ["l10n.toml"] + [
            mozpath.relpath(
                m["reference"].pattern.expand(m["reference"].env),
                basepath
            )
            for m in pc.paths
        ]
        self.paths_for_repos[repo.name] = paths
        branches = repo.branches()
        self.branches[repo.name] = branches[:]
        known_revs = self.revs.get(repo.name, {})
        if not process_revisions:
            return
        for branch_num in range(len(branches)):
            branch = branches[branch_num]
            prior_branches = branches[:branch_num]
            cmd = [
                "git", "-C", basepath,
                "log",
                "--parents",
                "--format=%H %ct %P"
            ] + [
                "^" + repo.ref(b) for b in prior_branches
            ]
            if branch in known_revs:
                cmd += ["^" + known_revs[branch]]
                block_revs = []
            elif branch_num == 0:
                # We haven't seen this repo yet.
                # Block all known revs in the target from being converted again
                # in case of repository-level forks.
                block_revs = self.target.known_revs()
            cmd += [repo.ref(branch), "--"] + paths
            out = subprocess.run(
                cmd,
                stdout=subprocess.PIPE, encoding="ascii"
            ).stdout
            for commit_line in out.splitlines():
                segs = commit_line.split()
                commit = segs.pop(0)
                if commit in block_revs:
                    continue
                commit_date = int(segs.pop(0))
                self.repos_for_hash[commit].append((repo.name, branch))
                self.hashes_for_repo[repo.name].add(commit)
                self.commit_dates[commit] = max(
                    commit_date, self.commit_dates.get(commit, 0)
                )
                for parent in segs:
                    self.parents[commit].add(parent)
                    self.children[parent].add(commit)
            if branch in known_revs or branch_num == 0:
                continue
            # We don't know this branch yet, and it's a fork.
            # Find the branch point to the previous branches.
            for prior_branch in prior_branches:
                cmd = [
                    "git",
                    "-C",
                    basepath,
                    "merge-base",
                    repo.ref(branch),
                    repo.ref(prior_branch),
                ]
                branch_rev = subprocess.run(
                    cmd, stdout=subprocess.PIPE, encoding="ascii"
                ).stdout.strip()
                if not branch_rev:
                    continue
                # We have a branch revision, find the next child on the
                # route to the prior branch to add that to.
                cmd = [
                    "git",
                    "-C",
                    basepath,
                    "rev-list",
                    "-n",
                    "1",
                    "{}..{}".format(branch_rev, repo.ref(prior_branch)),
                ]
                fork_rev = subprocess.run(
                    cmd, stdout=subprocess.PIPE, encoding="ascii"
                ).stdout.strip()
                if fork_rev:
                    self.forks[fork_rev].append(
                        (repo.name, branch, branch_rev)
                    )


class CommitWalker(walker.GraphWalker):
    def __init__(self, graph, branch):
        super(CommitWalker, self).__init__(graph)
        self.revs = {}
        for repo_name, revs in graph.revs.items():
            self.revs[repo_name] = revs.copy()
        self.target_branch = branch

    def repo(self, name):
        for repo in self.graph.repos:
            if repo.name == name:
                return repo

    def handlerev(self, src_rev):
        repo_name, branch = self.graph.repos_for_hash[src_rev][0]
        repo = self.repo(repo_name)
        self.revs[repo.name][branch] = src_rev
        if src_rev in self.graph.forks:
            for fork_repo, fork_branch, fork_rev in self.graph.forks[src_rev]:
                if fork_branch not in self.revs[fork_repo]:
                    self.revs[fork_repo][fork_branch] = fork_rev
        commitish = repo[src_rev]
        message = commitish.message + "\n"
        contents = defaultdict(list)
        for other_repo in self.graph.repos:
            other_revs = self.revs[other_repo.name]
            paths = self.graph.paths_for_repos[other_repo.name]
            other_branches = self.graph.branches[other_repo.name]
            for other_branch in other_branches:
                if other_branch not in other_revs:
                    continue
                other_rev = other_revs[other_branch]
                other_commit = other_repo[other_rev]
                for p in paths:
                    if p in other_commit.tree:
                        target_path = mozpath.join(other_repo.target_root, p)
                        contents[target_path].append(
                            other_repo[other_commit.tree[p].id].data
                        )
                message += "X-Channel{}-Revision: [{}] {}@{}\n".format(
                    "-Converted"
                    if other_repo.name == repo.name and other_branch == branch
                    else "",
                    other_branch,
                    other_repo.name,
                    other_rev,
                )
        self.createWorkdir(contents)
        self.createMeta(repo, self.revs[repo.name])
        self.graph.target.git.index.add_all()
        self.graph.target.git.index.write()
        tree_id = self.graph.target.git.index.write_tree()
        parents = []
        if not self.graph.target.git.is_empty:
            parents.append(self.graph.target.git.head.target)
        self.graph.target.git.create_commit(
            "refs/heads/" + self.target_branch,
            commitish.author,
            commitish.committer,
            message,
            tree_id,
            parents,
        )

    def createWorkdir(self, contents):
        workdir = self.graph.target.git.workdir
        locales = set()
        includes = []
        for tpath, content_list in contents.items():
            try:
                b_content = merge_channels(tpath, content_list)
            except MergeNotSupportedError:
                b_content = content_list[0]
            if tpath.endswith("l10n.toml"):
                try:
                    data = toml.loads(b_content)
                    if 'locales' in data:
                        locales.update(data['locales'])
                    includes.append(tpath)
                except Exception as e:
                    print(e)
                    pass
            tpath = mozpath.join(workdir, tpath)
            tdir = mozpath.dirname(tpath)
            if not os.path.isdir(tdir):
                os.makedirs(tdir)
            with open(tpath, "wb") as fh:
                fh.write(b_content)
        self.ensureL10nToml(workdir, locales, includes)

    def ensureL10nToml(self, workdir, locales, includes):
        locales = sorted(locales)
        includes.sort()
        with open(os.path.join(workdir, "l10n.toml"), "w") as l10n_toml:
            l10n_toml.write("basepath = \".\"\n\n")
            l10n_toml.write("locales = [\n")
            for locale in locales:
                l10n_toml.write("  \"{}\",\n".format(locale))
            l10n_toml.write("]\n\n")
            for include in includes:
                l10n_toml.write("""\
[[includes]]
    path = "{}"
""".format(include))

    def createMeta(self, repo, revs):
        workdir = os.path.join(self.graph.target.git.workdir, '_meta')
        if not os.path.isdir(workdir):
            os.makedirs(workdir)
        metafile = os.path.join(workdir, repo.name.replace('/', '-') + '.json')
        meta = {
            "name": repo.name,
            "revs": revs
        }
        with open(metafile, 'w') as fh:
            json.dump(meta, fh, sort_keys=True, indent=2)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--pull", action="store_true")
    p.add_argument("--repo", nargs="*")
    p.add_argument("target")
    p.add_argument("--branch", default="master")
    args = p.parse_args()
    graph = handle(args.target, args.branch, args.repo, pull=args.pull)
    echo = CommitWalker(graph, args.branch)
    echo.walkGraph()
