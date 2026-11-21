# Settings for the Claude bridge runner. Change a value, then restart the runner.
POLL_SECONDS=60     # how often it looks for new tasks
MAX_MINUTES=120     # longest a single unattended task may run before it is stopped
GITHUB_SYNC=1       # 1 keeps the bridge in step with its private GitHub copy; 0 turns that off

# Extra commands that unattended runs may never use, comma-separated, in Claude
# Code's permission-rule format. Add your own deploy or publish commands, e.g.:
# DENY_EXTRA="Bash(./deploy.sh *),Bash(make deploy *)"
DENY_EXTRA=""

# The runner only syncs to a GitHub repo that gh confirms is private. Set this to
# 1 only for a remote that is not on GitHub and that you know is private.
ALLOW_UNVERIFIED_REMOTE=0
