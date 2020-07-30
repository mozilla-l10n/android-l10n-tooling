# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

from __future__ import absolute_import, print_function, unicode_literals

from taskgraph.transforms.base import TransformSequence

transforms = TransformSequence()


@transforms.add
def update_l10n(config, jobs):
    secret_name = config.graph_config["github-token-secret"]

    for job in jobs:
        worker = job.setdefault("worker", {})
        run = job.setdefault("run", {})

        project = job["name"]
        repo_prefix = job.pop("repo-prefix")
        pr_target = job.pop("pr-target", "master")
        repo_name = project.split("/", 1)[1]

        job["description"] = job["description"].format(project=project)
        run["checkout"][repo_prefix] = {"path": project}
        run["command"] = [
            arg.format(project=project, repo_name=repo_name) for arg in run["command"]
        ]
        if config.params["level"] == "3":
            run["command"][1:1] = ["--pull-request={}".format(pr_target)]
            job.setdefault("scopes", []).append("secrets:get:{}".format(secret_name))
            worker["taskcluster-proxy"] = True
            worker.setdefault("env", {})["GITHUB_TOKEN_SECRET_NAME"] = secret_name

        yield job
