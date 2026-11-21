---
name: chat-code-bridge
description: Use when the user asks what Claude Code did, wants work done in a code project, or asks about a project's stack or rules. Passes work to Claude Code through ~/Developer/claude-bridge.
---

# Claude chat and Claude Code bridge (chat side)

The user's Claude Code sessions run on their Mac and keep their own memory in ~/.claude, which chat cannot read. Chat and Claude Code share work through the folder ~/Developer/claude-bridge/ (its README.md explains the folder). Use it so the two stay in step.

## 1. Get access
- Chat reaches the folder when this conversation is linked to the user's Mac in the Claude desktop app and their Developer folder is added (the + menu, then Add folder). Check your device tools for a connected Developer folder. With a device shell, the folder is usually at $HOME/mnt/Developer/claude-bridge.
- If the Mac is not linked (for example the user is on their phone), say so. If the bridge has a private GitHub copy, read it from there instead. Do not file tasks then. Draft the task in your reply so it can be filed later.
- If log.md has no "setup done" entry from Claude Code yet, remind the user once to send Claude Code: "Read ~/Developer/claude-bridge/SETUP-FOR-CLAUDE-CODE.md and do the setup steps in it."

## 2. Before answering about a project
Read, in this order:
1. projects.md, for the folder, stack, status file and rules file.
2. The top of log.md, for recent Claude Code work.
3. notes/<project>.md and notes/_all-projects.md.
4. The status or rules files that projects.md names, when they matter.

Trust these over your own memory for the stack, deploy steps and rules. Chat memory goes out of date.

Read git history only with `GIT_OPTIONAL_LOCKS=0 git --no-optional-locks -C <repo> log ...`. Never run git commit, pull, stash, checkout, merge or reset through a device shell: deleting can be disabled there, and git then leaves lock files behind that break the user's next git command.

## 3. Sending work to Claude Code
- Create tasks/<YYYY-MM-DD>-<project>-<short-name>.md from tasks/_TEMPLATE.md. Fill every Brief line: the task with exact pages or files, why, the user's rules that apply, what done looks like, and what needs their OK first (deploys, pushes, posts, emails and account changes always do, unless they said otherwise). Quote their go-ahead with its date when they gave one.
- Write the file under a name that starts with "_" and rename it when it is complete, so the runner never picks up a half-written task.
- "Run: auto" makes the runner start Claude Code on it within a minute, when the runner is running. Use it only for clear tasks worth doing unattended, because runs use the user's Claude plan. Otherwise use "Run: manual" and tell the user in one line: open Claude Code on that project and say "do the chat tasks".
- Do not edit files inside the project folders yourself. Claude Code owns them.

## 4. Recording decisions
When the user makes a decision or sets a rule for a project in chat, add one dated line under "From chat" in notes/<project>.md (create it from notes/_TEMPLATE.md if it is missing). If it changes an earlier line, edit that line instead of adding a contradiction. Say in one short line that it is noted for Claude Code.

## 5. Reporting what Claude Code did
Read the project's newest log.md entries, the Result section of any task file, and its status file. Summarise in plain words: what changed, the links, and what waits on the user. Never say something is live unless the log or the status file says it was deployed.

## Rules
- Edit bridge files by appending or editing in place. Never rebuild a file from an earlier tool result, which may be cut short.
- Never put passwords, API keys, tokens, one-time codes, card or bank numbers, or other people's private data in the bridge. Anything personal goes in private/, which never leaves the Mac.
- Keep entries short and dated, with the time zone.
