# Brainstorm - Maestro

This must be a tool for building agent workflows. You pick a project, type a task, you decide the steps, which AI CLI and which model will execute each one of the steps, hen runs the whole thing on a branch in the background. The same CLI can perform all the task if you want to.

## Example

- Task: Implement Use Case 01 based on documentation
  - Steps:
    - Plan:
      - CLI: Claude;
      - Model: Opus
    - Execute:
      - CLI: Codex
      - Model: Terra
    - Review:
      - CLI: Claude
      - Model: Opus

## Specs

- The only required step is Execute, but the default must be Plan, Execute and Review.
- Two modes must be available:
  - Autonomous: all PRs are reviewed by a model and merged by a model, with no user intervention
  - Supervised (default): all PRs must be reviwed and merged by the user
- More than one workflow can be executed simultaneosly
- The user can view the executions logs in real time
- After a workflow is started the user must see a visual representation of it, showing the current step and logs
- The workflow runs are stored in a history, that can be accessed
- Runs can be canceled and paused
- A failed or canceled run can be retried, a pause run can be resumed
- Each run is associated with a project, that is a folder opened by this tool
- The projects must be shown in a left panel
- The tool must open inside it a powershell 7 window at the project's folder for windows and a bash for linux

- Technologies

- Flutter for the interface
- There must be a windows app and a linux too
- Evaluate the best technology for the backend
- Evaluate if a database is needed, if so, use SQLite
