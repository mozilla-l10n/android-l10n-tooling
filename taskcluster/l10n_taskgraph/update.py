# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


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
        pr_target = job.pop("pr-target")

        job["description"] = job["description"].format(project=project)

        if "firefox-android" in project:
            org_name, repo_name, project = project.split("/")
            project = "{}/{}".format(org_name, repo_name)

        run["checkout"][repo_prefix] = {"path": project}
        if config.params["level"] == "3":
            run["command"][1:1] = [f"--pull-request={pr_target}"]
            job.setdefault("scopes", []).append(f"secrets:get:{secret_name}")
            worker["taskcluster-proxy"] = True
            worker.setdefault("env", {})["GITHUB_TOKEN_SECRET_NAME"] = secret_name

        yield job


@transforms.add
def add_l10n_toml_path(config, jobs):
    for job in jobs:
        project = job["name"]

        repo_name = project.split("/")[1]
        if "firefox-android" in project:
            repo_name = "{}-{}".format(repo_name, project.split("/")[2])

        l10n_toml_path = job.pop("l10n-toml-path", "")
        l10n_toml_path = l10n_toml_path.format(project=project)

        run = job.setdefault("run", {})
        run["command"] = [
            arg.format(
                project=project,
                repo_name=repo_name,
                l10n_toml_path=l10n_toml_path,
            ) for arg in run["command"]
        ]

        yield job
