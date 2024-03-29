# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


from taskgraph.target_tasks import _target_task


@_target_task("update-l10n")
def target_tasks_l10n(full_task_graph, parameters, graph_config):
    def filter(task, parameters):
        return task.kind == "update-l10n"

    return [l for l, t in full_task_graph.tasks.items() if filter(t, parameters)]


@_target_task("update-projects")
def target_tasks_project(full_task_graph, parameters, graph_config):
    """Select the set of tasks required for a nightly build."""

    def filter(task, parameters):
        return task.kind == "update-project"

    return [l for l, t in full_task_graph.tasks.items() if filter(t, parameters)]
