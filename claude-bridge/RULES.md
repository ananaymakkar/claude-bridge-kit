# Claude chat and Claude Code bridge: rules for every Claude Code session

The owner of this Mac also works with Claude in the Claude app (chat). Chat cannot see your sessions, your memory or your CLAUDE.md files, and you cannot see chat. The folder ~/Developer/claude-bridge/ is the shared desk between you. Details and file formats: ~/Developer/claude-bridge/README.md.

When you start, once you know which project you are on (names in ~/Developer/claude-bridge/projects.md):
1. Read ~/Developer/claude-bridge/notes/<project>.md and notes/_all-projects.md. They hold rules and decisions the owner gave in chat. If a chat decision is missing from your own rules (the project's docs, CLAUDE.md, your memory), add it there and mark the line "synced <date>" in the note. If it contradicts your rules, change neither and ask the owner.
2. Check ~/Developer/claude-bridge/tasks/ for files with your project and "Status: open". Tell the owner in one line what is waiting. Start one only when the owner asks, or says "do the chat tasks". Tasks marked "Run: auto" belong to the runner, so leave those unless asked. If the runner started you (your prompt says you are unattended), skip this step and do only your own task.

While you work: when the owner makes a decision or sets a rule, also add one dated line to notes/<project>.md under "From Claude Code", so chat knows it.

After each finished piece of work (a commit, a deploy, a report), and whenever you stop to wait for the owner:
- Add an entry at the top of ~/Developer/claude-bridge/log.md: date, time and time zone, project, what changed with the commit or link, and what waits on the owner.
- If you worked on a task file, fill in its Result section and update its Status.

Never put passwords, API keys, tokens, one-time codes, card or bank numbers, or other people's private data in the bridge. Anything personal goes in ~/Developer/claude-bridge/private/, which never leaves this Mac: never copy it into a repo, a commit, a deploy or anything else that leaves the Mac.
