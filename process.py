import argparse
from collections import defaultdict
import os
import re
import shutil
import subprocess

import pytoml as toml
import pygit2
from compare_locales.paths import TOMLParser
from compare_locales import mozpath
from compare_locales.merge import merge_channels
import walker


def handle(target, pull=False):
    graph = CommitsGraph(target)
    graph.loadConfigs()
    graph.loadRevs()
    if pull:
        graph.pull()
    graph.gather()
    return graph


class CommitsGraph:

    def __init__(self, target):
        self.config = None
        self.repos = None
        self.repos_for_hash = defaultdict(list)
        self.paths_for_repos = {}
        self.commit_dates = {}
        self.parents = defaultdict(set)
        self.children = defaultdict(set)
        self.target = pygit2.Repository(target)
        self.revs = {}

    def loadRevs(self):
        if self.target.is_empty:
            return
        cmd = [
            'git',
            '-C', self.target.path, 
            'log', 
            '-n', '1', 
            '--grep=Converted:', 
            '--format=%H',
        ]
        last_converted = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            encoding='ascii'
        ).stdout.strip()
        head = self.target[last_converted]
        revs = {}
        for m in re.finditer(
            '^(Converted: )?([^@\n]*?)@([a-f0-9]{40})$',
            head.message,
            re.M
        ):
            revs[m.group(2)] = m.group(3)
        for repo in self.repos:
            n = '{org}/{name}'.format(**repo)
            if n in revs:
                self.revs[n] = revs.pop(n)
        if revs:
            assert false, 'Configuration dropped'

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
        self.repos = toml.load(open('config.toml'))['repo']

    def pull(self):
        for repo in self.repos:
            basepath = mozpath.join(repo['org'], repo['name'])
            cmd = [
                'git',
                '-C', basepath,
                'pull'
            ]
            subprocess.run(cmd)

    def gather(self):
        for repo in self.repos:
            self.gather_repo(repo)

    def gather_repo(self, repo):
        basepath = mozpath.join(repo['org'], repo['name'])
        pc = TOMLParser().parse(mozpath.join(basepath, 'l10n.toml'))
        paths = [
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
            oldparent = None
            if basepath in self.revs:
                oldparent = self.revs[basepath]
                cmd += ['^' + self.revs[basepath]]
            cmd += [
                branch,
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
                    if parent == oldparent:
                        continue
                    self.parents[commit].add(parent)
                    self.children[parent].add(commit)


class EchoWalker(walker.GraphWalker):
    def __init__(self, graph):
        super(EchoWalker, self).__init__(graph)
        self._repos = {}
        self.revs = graph.revs.copy()

    def repo(self, path):
        if path not in self._repos:
            self._repos[path] = pygit2.Repository(path)
        return self._repos[path]

    def handlerev(self, src_rev):
        basepath, branch = self.graph.repos_for_hash[src_rev][0]
        repo = self.repo(basepath)
        self.revs[basepath] = src_rev
        commitish = repo[src_rev]
        message = commitish.message + '\nConverted: {}@{}\n'.format(basepath, src_rev)
        contents = defaultdict(list)
        for other_path, other_rev in self.revs.items():
            paths = self.graph.paths_for_repos[other_path]
            other_repo = self.repo(other_path)
            other_commit = other_repo[other_rev]
            for p in paths:
                if p in other_commit.tree:
                    target_path = mozpath.join(*mozpath.split(p)[-2:])
                    contents[target_path].append(other_repo[other_commit.tree[p].id].data)
            if other_path == basepath:
                continue
            message += '{}@{}\n'.format(other_path, other_rev)
        self.createWorkdir(contents)
        self.graph.target.index.add_all()
        self.graph.target.index.write()
        tree_id = self.graph.target.index.write_tree()
        parents = []
        if not self.graph.target.is_empty:
            parents.append(self.graph.target.head.target)
        self.graph.target.create_commit(
            'refs/heads/master',
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
            shutil.rmtree(mozpath.join(workdir, entry))
        for tpath, content_list in contents.items():
            b_content = merge_channels(tpath, content_list)
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
    args = p.parse_args()
    graph = handle(args.target, pull=args.pull)
    echo = EchoWalker(graph)
    echo.walkGraph()
