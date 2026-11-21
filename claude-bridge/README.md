# Claude bridge

A shared desk where Claude chat (the Claude app) and Claude Code pass work to each other.

Why it exists: Claude chat and Claude Code do not share conversations or memory. Decisions you make in chat never reach Claude Code, and chat cannot see what Claude Code has done. Everything here is plain text that both of them can read and write.

## What is in this folder
- **RULES.md**: the short rules every Claude Code session loads, through one import line in ~/.claude/CLAUDE.md.
- **projects.md**: every project, its folder, GitHub repo, live site, and where its status and rules are kept.
- **tasks/**: work that chat hands to Claude Code, one file per task. Claude Code writes the result into the same file.
- **log.md**: what Claude Code did, newest first. Chat reads this first.
- **notes/**: shared memory per project. Chat adds decisions you make in chat. Claude Code adds decisions made in Claude Code, and the standing rules from its own memory that chat cannot see. notes/_all-projects.md holds the rules that apply everywhere.
- **private/** (make it when you need it): anything personal that must stay on this Mac. It is git-ignored, so it never goes to GitHub.
- **SETUP-FOR-CLAUDE-CODE.md**: the one-time setup that Claude Code does.
- **_system/**: the runner that starts Claude Code by itself (runner.sh), its one-time installer (install.sh), its settings (config.sh), the project folders it uses (projects.txt), and its run logs (runs/, kept on the Mac only).

## How you use it
- In chat: "send this to Claude Code". Chat writes a task file. If it is marked "Run: auto" and the runner is running, Claude Code starts on it within a minute, and a Mac notification tells you when it finishes or needs you.
- In Claude Code: "do the chat tasks". Claude Code also mentions open tasks when a session starts on that project.
- In chat: "what did Claude Code do on my website?" Chat reads log.md and the task files.
- Chat can read and write this folder only when your Developer folder is added to that chat in the Claude desktop app (the + menu, then Add folder).

## The runner: Claude Code starts by itself
_system/runner.sh checks tasks/ every minute. For each task with "Status: open" and "Run: auto", it starts Claude Code, unattended, in that project's folder (from _system/projects.txt). Claude Code writes its result into the task file and log.md.
- **First time:** run `bash ~/Developer/claude-bridge/_system/install.sh` in Terminal. It checks Claude Code, offers the private GitHub copy and starts the runner.
- **Start:** double-click _system/Start Bridge Runner.command and keep its Terminal window open (it can sit in the background). **Stop:** Ctrl+C, or close the window. **Pause:** create the file _system/PAUSE, and delete it to resume.
- **Is it running?** _system/.runner.lock/heartbeat holds the time of its last check.
- **Safety for unattended runs:** auto permission mode with permission prompts turned off. Pushing to GitHub, common deploy commands (Vercel, Netlify, Cloudflare Wrangler, Firebase, Fly), npm publish, merging pull requests and all connector tools (mail, browsers, accounts) are denied outright. Add your own deploy commands to DENY_EXTRA in _system/config.sh. With "Workspace: separate", Claude Code works in a new git worktree made from the project's current commit, so the main folder and any session open there are untouched. A run stops after 120 minutes. Anything that needs you ends as "waiting on owner".
- **Picking up a run:** the task file ends with a line like `claude --desktop --resume <session>`. Run it in Terminal to open that session in the Claude app with everything it did, then approve, merge or deploy there.
- **Housekeeping:** each separate run leaves a worktree in <project>/.claude/worktrees/. Once its branch is merged or dropped, Claude Code can remove it. The runner adds `.claude/worktrees/` to each repo's local git exclude list, so these folders never make the main folder look changed.
- Runs use your Claude plan, like any Claude Code session, so mark a task "Run: auto" only when it is clear and worth doing unattended.

## The GitHub copy (optional)
install.sh can back the bridge up to a private repo named claude-bridge on your GitHub account. The runner then commits and syncs every minute, so chat on your phone can read the bridge through the GitHub copy. Run logs stay on the Mac, and so does private/. The runner only syncs to a repo that the GitHub command-line tool (gh) confirms is private. If the Mac's and GitHub's versions ever clash, the runner keeps both, notes it in _system/runs/sync.log and shows a notification. Ask Claude Code to merge them.

## Formats
**Task file:** tasks/<YYYY-MM-DD>-<project>-<short-name>.md, made from tasks/_TEMPLATE.md. Status is one of: open, in progress, waiting on owner, done, dropped. Files whose names start with "_" are ignored by the runner, so a task can be written under a "_" name and renamed when it is complete.

**log.md entry:**
```
## <date> <time> <time zone> · <project>
- Did: <what changed>
- Commit / link: <commit id, live or preview URL>
- Waiting on owner: <question or approval, or "nothing">
- Task: <tasks/... file, if any>
```

**notes/<project>.md:** dated one-line entries under "From chat" or "From Claude Code". When a rule changes, edit the old line (keep the date of the change) instead of adding a contradicting one.

## Housekeeping
- Keep log.md under about 300 lines. Move older entries to log-archive/<YYYY-MM>.md.
- Move done tasks older than 30 days into tasks/done/.
- Never store passwords, API keys, tokens, one-time codes, card or bank numbers, or other people's private data here.

## Limits
- Chat away from the Mac, and Claude Code cloud sessions, can reach the bridge only through its GitHub copy.
- The runner works only while the Mac is awake and its Terminal window is open.
- Chat cannot read ~/.claude, where Claude Code keeps its memory. That is why Claude Code copies the rules chat needs into notes/.
