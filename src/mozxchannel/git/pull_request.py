# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import os
import subprocess


def create(target, target_branch, *, title, message, branch=None):
    # git pull-request creates a PR from the current branch, so switch to it.
    if branch:
        cmd = ["git", "-C", target, "checkout", branch]
        subprocess.run(cmd, check=True)

    # git pull-request will sometimes open an editor, ensure this succeeds
    env = os.environ.copy()
    env["EDITOR"] = "true"
    cmd = ["git", "-C", target, "pull-request", "--target-branch", target_branch, "--title", title, "--message", message]
    try:
        subprocess.run(cmd, env=env, check=True)
    except subprocess.CalledProcessError as exc:
        # Work around https://github.com/mozilla-l10n/android-l10n-tooling/issues/13
        if exc.returncode == 50:
            print("No changes found; exiting.")
        else:
            raise exc
