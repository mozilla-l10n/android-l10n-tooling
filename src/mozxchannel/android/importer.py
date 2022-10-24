import argparse
import os
import shutil
import subprocess
from compare_locales.paths import TOMLParser

from mozxchannel.git import pull_request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('l10n_toml', help='l10n.toml with localizations')
    parser.add_argument('dest', help='Destination repository')
    parser.add_argument("--pull-request", default=None)
    args = parser.parse_args()

    porter = Importer(args.l10n_toml, args.dest)
    porter.import_strings()

    subprocess.run(
        ["git", "-C", args.dest, "checkout", "-B", "import-l10n"], check=True
    )
    subprocess.run(
        ["git", "-C", args.dest, "add", "-v", "-A"], check=True
    )
    diff = subprocess.run(
        ["git", "-C", args.dest, "diff", "--cached", "--exit-code"]
    )
    if diff.returncode == 0:
        print("No changes")
        return
    subprocess.run(
        ["git", "-C", args.dest, "commit", "-m", "Import l10n."], check=True
    )
    if args.pull_request:
        pull_request.create(
            args.dest, args.pull_request, title="Import strings from android-l10n.", message="n/t"
        )


class Importer(object):
    def __init__(self, l10n_toml, dest):
        self.src_toml = l10n_toml
        if dest == "mozilla-mobile/firefox-android" and "android-components" in l10n_toml:
            dest = "mozilla-mobile/android-components"
        self.dest_toml = os.path.join(dest, 'l10n.toml')
        self.dest = dest
        self.src_config = self.dest_config = None

    def import_strings(self):
        self.read_configs()
        self.clean_l10n()
        self.copy_toml()
        self.copy_l10n()

    def read_configs(self):
        parser = TOMLParser()
        self.src_config = parser.parse(self.src_toml)
        self.dest_config = parser.parse(self.dest_toml)

    def clean_l10n(self):
        for dest_paths in self.dest_config.paths:
            matcher = dest_paths['l10n']
            for root, dirs, files in self._walk_matcher(matcher):
                for file in files:
                    file = os.path.join(root, file)
                    if matcher.match(file) is not None:
                        os.remove(file)
                if not os.listdir(root):
                    os.removedirs(root)


    def copy_toml(self):
        shutil.copy2(self.src_toml, self.dest_toml)
        self.dest_config = TOMLParser().parse(self.dest_toml)

    def copy_l10n(self):
        for src_paths, dest_paths in zip(
            self.src_config.paths, self.dest_config.paths
        ):
            self.copy_l10n_for_matcher(
                src_paths['l10n'], dest_paths['l10n'], dest_paths['reference']
            )

    def copy_l10n_for_matcher(self, src_matcher, dest_matcher, dest_ref):
        for root, dirs, files in self._walk_matcher(src_matcher):
            for file in files:
                file = os.path.join(root, file)
                dest = src_matcher.sub(dest_matcher, file)
                if dest is None:
                    continue
                dest_dir = os.path.dirname(dest)
                if not os.path.isdir(dest_dir):
                    os.makedirs(dest_dir)
                # TODO: remove obsolete entries
                shutil.copy2(file, dest)

    def _walk_matcher(self, matcher):
        prefix = matcher.prefix
        basedir = prefix
        while not os.path.isdir(basedir):
            basedir = os.path.dirname(basedir)
        for root, dirs, files in os.walk(basedir):
            filtered_dirs = [
                dir for dir in dirs
                if os.path.join(root, dir).startswith(prefix)
            ]
            dirs[:] = filtered_dirs
            yield root, dirs, files

if __name__ == '__main__':
    main()
