# One-time setup for Claude Code

**You:** open Claude Code in any project and send this one line:

> Read ~/Developer/claude-bridge/SETUP-FOR-CLAUDE-CODE.md and do the setup steps in it.

**Claude Code:** do these steps in order. Ask the owner before doing anything not listed here. After each step, tell the owner in one short line what changed.

1. **Load the bridge rules in every session.** Add these two lines at the end of ~/.claude/CLAUDE.md (create the file if it is missing, and skip this if the import line is already there):
   ```
   # Claude chat bridge
   @~/Developer/claude-bridge/RULES.md
   ```
   If Claude Code asks for approval of the external import, the owner approves it.

2. **List the projects.** Ask the owner which projects they work on with you. For each one, add a row to projects.md (folder, GitHub repo, live site, where its status and its rules are kept), a line to _system/projects.txt (bridge name and folder), and a notes/<name>.md made from notes/_TEMPLATE.md. Use short lowercase names with hyphens.

3. **Copy the rules chat needs.** Chat cannot read ~/.claude. From ~/.claude/CLAUDE.md, your memory (MEMORY.md and the topic files under ~/.claude/projects/*/memory/) and each project's own rules docs, add the owner's standing rules to the "From Claude Code" section of:
   - notes/_all-projects.md, for rules that apply everywhere
   - notes/<project>.md, for each project
   One dated line each, in plain words, most important first, at most about 40 lines per file. Point to the source file instead of copying long passages. No secrets and no other people's private data.

4. **Sync the other way.** Read every "From chat" section. Add each item that is missing from your rules to the right place (the project's rules doc or your memory) and mark it "synced <date>". If a chat item contradicts your rules, change neither and list it for the owner.

5. **GitHub copy and runner.** These are optional and set up by the owner running `bash ~/Developer/claude-bridge/_system/install.sh` in Terminal. If ~/Developer/claude-bridge has no git remote yet, mention it once. Do not push the bridge yourself: the runner syncs it.

6. **Write the first log entry** at the top of log.md: "setup done", plus anything from step 4 that needs the owner's decision.

7. **Check the rule loads.** Ask the owner to start a new Claude Code session and ask: "What does the Claude chat bridge rule say?" If the new session does not know, copy the text of RULES.md into ~/.claude/CLAUDE.md directly instead of the import line.
