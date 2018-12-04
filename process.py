import argparse
from collections import defaultdict, OrderedDict
import os
import re
import shutil
import subprocess

import pytoml as toml
import pygit2
from compare_locales.paths import TOMLParser
from compare_locales import mozpath
from compare_locales.merge import merge_channels, MergeNotSupportedError
import walker


def handle(target, target_branch, pull=False):
    graph = CommitsGraph(target, target_branch)
    graph.loadConfigs()
    if pull:
        graph.pull()
    graph.loadRevs()
    graph.gather()
    return graph


class CommitsGraph:

    def __init__(self, target, branch):
        self.config = None
        self.repos = None
        self.repos_for_hash = defaultdict(list)
        self.paths_for_repos = {}
        self.commit_dates = {}
        self.parents = defaultdict(set)
        self.children = defaultdict(set)
        self.target = pygit2.Repository(target)
        self.target_branch = branch
        self.revs = {}

    def loadRevs(self):
        if self.target.is_empty:
            return
        cmd = [
            'git',
            '-C', self.target.path, 
            'log', 
            '-n', '1', 
            '--grep=X-Channel-Converted-Revision:',
            '--format=%H',
            self.target_branch
        ]
        last_converted = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            encoding='ascii'
        ).stdout.strip()
        if not last_converted:
            last_converted = self.target.lookup_branch(self.target_branch).target
        head = self.target[last_converted]
        revs = defaultdict(dict)
        for m in re.finditer(
            '^X-Channel-(?:Converted-)?Revision: '
            '\[(?P<branch>.+?)\] (?P<repo>[^@\n]*?)@(?P<rev>[a-f0-9]{40})$',
            head.message,
            re.M
        ):
            revs[m.group('repo')][m.group('branch')] = m.group('rev')
        for repo in self.repos:
            repo_name = '{org}/{name}'.format(**repo)
            if repo_name not in revs:
                continue
            self.revs[repo_name] = OrderedDict()
            for n, branch in enumerate(repo['branches']):
                if branch in revs[repo_name]:
                    self.revs[repo_name][branch] = revs[repo_name][branch]
                    continue
                # Find branch point against earlier branches
                # This assumes that forks and releases come after
                # their development branches. Aka, `master` should be the
                # first branch in `config.toml`.
                if n == 0:
                    # first branch, nothing to check against
                    continue
                cmd = [
                    'git',
                    '-C', repo_name,
                    'merge-base',
                    'origin/' + branch
                ] + [
                    'origin/' + b
                    for b in repo['branches'][:n]
                ]
                branch_rev = subprocess.run(
                    cmd,
                    stdout=subprocess.PIPE,
                    encoding='ascii'
                ).stdout.strip()
                if branch_rev:
                    self.revs[repo_name][branch] = branch_rev

    @property
    def roots(self):
        roots = list(set(self.children) - set(self.parents))
        if roots:
            return roots
        if len(self.repos_for_hash) == 1:
            # only one commit, we don't have parents or children,
            # but something to do
            roots += self.repos_for_hash.keys()
        return roots

    def loadConfigs(self):
        config_path = os.path.join(self.target.workdir, 'config.toml')
        self.repos = toml.load(open(config_path))['repo']

    def pull(self):
        for repo in self.repos:
            basepath = mozpath.join(repo['org'], repo['name'])
            cmd = [
                'git',
                '-C', basepath,
                'pull',
                '-q',
            ]
            subprocess.run(cmd)

    def gather(self):
        for repo in self.repos:
            self.gather_repo(repo)

    def gather_repo(self, repo):
        basepath = mozpath.join(repo['org'], repo['name'])
        pc = TOMLParser().parse(mozpath.join(basepath, 'l10n.toml'))
        paths = ['l10n.toml'] + [
            mozpath.relpath(
                m['reference'].pattern.expand(m['reference'].env),
                basepath
            )
            for m in pc.paths
        ]
        self.paths_for_repos[basepath] = paths
        for branch in repo['branches']:
            cmd = [
                'git',
                '-C', basepath,
                'log',
                '--parents',
                '--format=%H %ct %P']
            base_revisions = None
            if basepath in self.revs:
                base_revisions = self.revs[basepath].values()
                cmd += ['^' + r for r in base_revisions]
            cmd += [
                'origin/' + branch,
                '--'
            ] + paths
            out = subprocess.run(cmd, stdout=subprocess.PIPE, encoding='ascii').stdout
            for commit_line in out.splitlines():
                segs = commit_line.split()
                commit = segs.pop(0)
                commit_date = int(segs.pop(0))
                self.repos_for_hash[commit].append((basepath, branch))
                self.commit_dates[commit] = max(commit_date, self.commit_dates.get(commit, 0))
                for parent in segs:
                    if base_revisions and parent in base_revisions:
                        continue
                    self.parents[commit].add(parent)
                    self.children[parent].add(commit)


class EchoWalker(walker.GraphWalker):
    def __init__(self, graph, branch):
        super(EchoWalker, self).__init__(graph)
        self._repos = {}
        self.revs = defaultdict(dict)
        for repo_name, revs in graph.revs.items():
            self.revs[repo_name] = revs.copy()
        self.target_branch = branch

    def repo(self, path):
        if path not in self._repos:
            if not os.path.isdir(path):
                # try bare repo
                path += '.git'
            self._repos[path] = pygit2.Repository(path)
        return self._repos[path]

    def handlerev(self, src_rev):
        basepath, branch = self.graph.repos_for_hash[src_rev][0]
        repo = self.repo(basepath)
        self.revs[basepath][branch] = src_rev
        commitish = repo[src_rev]
        message = (
            commitish.message +
            '\n'
        )
        contents = defaultdict(list)
        for other_path, other_revs in self.revs.items():
            paths = self.graph.paths_for_repos[other_path]
            other_repo = self.repo(other_path)
            for other_branch, other_rev in other_revs.items():
                other_commit = other_repo[other_rev]
                for p in paths:
                    if p in other_commit.tree:
                        target_path = mozpath.join(other_path, p)
                        contents[target_path].append(
                            other_repo[other_commit.tree[p].id].data
                        )
                message += 'X-Channel{}-Revision: [{}] {}@{}\n'.format(
                    '-Converted' if other_path == basepath and other_branch == branch else "",
                    other_branch,
                    other_path, other_rev
                )
        self.createWorkdir(contents)
        self.graph.target.index.add_all()
        self.graph.target.index.write()
        tree_id = self.graph.target.index.write_tree()
        parents = []
        if not self.graph.target.is_empty:
            parents.append(self.graph.target.head.target)
        self.graph.target.create_commit(
            'refs/heads/' + self.target_branch,
            commitish.author,
            commitish.committer,
            message,
            tree_id,
            parents
        )

    def createWorkdir(self, contents):
        workdir = self.graph.target.workdir
        for entry in os.listdir(workdir):
            if entry[0] == '.':
                continue
            if entry == 'config.toml':
                continue
            shutil.rmtree(mozpath.join(workdir, entry))
        for tpath, content_list in contents.items():
            try:
                b_content = merge_channels(tpath, content_list)
            except MergeNotSupportedError:
                b_content = content_list[0]
            tpath = mozpath.join(workdir, tpath)
            tdir = mozpath.dirname(tpath)
            if not os.path.isdir(tdir):
                os.makedirs(tdir)
            with open(tpath, 'wb') as fh:
                fh.write(b_content)


if __name__=='__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--pull', action="store_true")
    p.add_argument('target')
    p.add_argument('--branch', default="master")
    args = p.parse_args()
    graph = handle(args.target, args.branch, pull=args.pull)
    echo = EchoWalker(graph, args.branch)
    echo.walkGraph()
