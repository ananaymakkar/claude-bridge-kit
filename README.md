# Claude bridge kit

Claude chat (the Claude app) and Claude Code don't share conversations or memory. You decide something in chat and Claude Code never hears about it. Claude Code finishes a job and chat can't see what it did.

This kit fixes that with one shared folder on your Mac, `~/Developer/claude-bridge`:

- Chat writes tasks for Claude Code and records the decisions you make in chat.
- Claude Code reads them in every session, does the work, and writes back what it did.
- An optional runner starts Claude Code by itself on tasks that chat marks "Run: auto", so you can hand work over from chat and come back to the result.

It is all plain text files on your Mac. The only thing that leaves your Mac is the optional private GitHub backup.

## How it works

| | Claude chat | Claude Code |
|---|---|---|
| Handing over work | writes a task file in `tasks/` | writes the result into the same file |
| Remembering decisions | adds them to `notes/<project>.md` under "From chat" | adds its own standing rules under "From Claude Code" |
| Knowing what happened | reads `log.md` | adds an entry to `log.md` after each piece of work |

## What you need

- A Mac. The runner and the installer are written for macOS.
- Claude Code, installed and signed in.
- The Claude desktop app, so chat can reach the folder. In a chat, use the + menu, then Add folder, and pick your Developer folder.
- Optional: git and the GitHub command-line tool (`gh`), signed in, for a private backup that chat can also read from your phone.

## Set it up (about 10 minutes)

1. **Copy the folder into place.** In Terminal:
   ```
   git clone https://github.com/ananaymakkar/claude-bridge-kit.git /tmp/claude-bridge-kit
   mkdir -p ~/Developer && cp -R /tmp/claude-bridge-kit/claude-bridge ~/Developer/claude-bridge
   ```
   Don't clone this repo straight into `~/Developer/claude-bridge`. Your bridge will hold your own notes, so it should never be linked to a public repo.

2. **Set up Claude Code.** Open Claude Code in any project and send:
   > Read ~/Developer/claude-bridge/SETUP-FOR-CLAUDE-CODE.md and do the setup steps in it.

   It adds one import line to `~/.claude/CLAUDE.md` so every session follows the bridge rules, asks which projects you work on, and copies its standing rules into `notes/` so chat can see them.

3. **Set up chat.** Add the skill in `chat-skill/` to your Claude account. Upload `chat-skill/chat-code-bridge.zip` under Customize, Skills, the + button, Create skill, Upload a skill. Skills need "Code execution and file creation" turned on in Settings, Capabilities ([Anthropic's guide to skills](https://support.claude.com/en/articles/12512180)). Then add your Developer folder to the chat (+ menu, Add folder).

4. **Optional: the runner and the GitHub backup.** In Terminal:
   ```
   bash ~/Developer/claude-bridge/_system/install.sh
   ```
   It checks that Claude Code is signed in, offers a private GitHub repo for the bridge, and starts the runner in its own Terminal window.

## Everyday use

- In chat: "send this to Claude Code." Chat writes a task file.
- In Claude Code: "do the chat tasks."
- In chat: "what did Claude Code do on the website?"
- Make a decision in chat and chat writes it into that project's notes. Claude Code adds it to its own rules the next time it works on the project.

## Safety

- Unattended runs can't push to GitHub, deploy (Vercel, Netlify, Wrangler, Firebase, Fly), publish to npm, merge pull requests or use connector tools such as mail and browsers. Add your own deploy commands to `DENY_EXTRA` in `_system/config.sh`.
- By default a run works in a separate git worktree, so your main folder stays untouched, and it stops after 120 minutes.
- Anything that needs you ends as "waiting on owner", with a command that reopens that exact session.
- The runner only syncs to a GitHub repo that `gh` confirms is private, and the bridge's `private/` folder is git-ignored for anything personal.
- Never put passwords, keys or one-time codes in the bridge.
- Runs use your Claude plan, like any Claude Code session.

## Limits

- The runner needs your Mac awake, with its Terminal window open.
- Away from the Mac, chat can only read the bridge through the private GitHub copy.
- Chat still can't read Claude Code's memory folder (`~/.claude`). That is why Claude Code copies the rules chat needs into `notes/`.

## What's inside

- `claude-bridge/`: the folder that goes in `~/Developer/claude-bridge` (rules, templates, the runner and its installer).
- `chat-skill/`: the skill that teaches Claude chat to use the folder.

## Licence

MIT. Made by Ananay Makkar, built with Claude chat and Claude Code.
