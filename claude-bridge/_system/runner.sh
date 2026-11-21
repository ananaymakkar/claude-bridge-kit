#!/bin/bash
# Claude bridge runner.
# Watches ~/Developer/claude-bridge/tasks/ for task files with "Status: open" and
# "Run: auto", starts Claude Code on each one by itself, and keeps the bridge in
# step with its private GitHub copy.
#
# Start:  double-click "Start Bridge Runner.command", or run
#         bash ~/Developer/claude-bridge/_system/runner.sh
# Stop:   Ctrl+C in its window, or close the window.
# Pause:  create the file ~/Developer/claude-bridge/_system/PAUSE (delete it to resume).
# Alive?  _system/.runner.lock/heartbeat holds the time of the runner's last check.
#
# Written for the bash 3.2 that ships with macOS: no associative arrays, no mapfile.

BRIDGE="${BRIDGE_DIR:-$HOME/Developer/claude-bridge}"
SYS="$BRIDGE/_system"
TASKS="$BRIDGE/tasks"
RUNS="$SYS/runs"
LOCK="$SYS/.runner.lock"

# Settings (override them in _system/config.sh).
POLL_SECONDS=60
MAX_MINUTES=120
GITHUB_SYNC=1
[ -f "$SYS/config.sh" ] && . "$SYS/config.sh"
MAX_SECONDS="${MAX_SECONDS:-$((MAX_MINUTES * 60))}"

# Commands an unattended run may never use. Auto mode allows pushing to a branch,
# so pushing and deploying are denied outright; "mcp__*" removes connector tools
# (mail, browsers, accounts) from unattended runs.
DENY_RULES="Bash(git push *),Bash(git push),Bash(vercel *),Bash(npx vercel *),Bash(npx vercel@latest *),Bash(netlify deploy *),Bash(npx netlify deploy *),Bash(wrangler deploy *),Bash(npx wrangler deploy *),Bash(firebase deploy *),Bash(npx firebase deploy *),Bash(fly deploy *),Bash(flyctl deploy *),Bash(npm publish *),Bash(npm publish),Bash(gh pr merge *),Bash(gh repo delete *),Bash(gh release create *),mcp__*"
# Your own deploy commands go in DENY_EXTRA in _system/config.sh.
[ -n "${DENY_EXTRA:-}" ] && DENY_RULES="$DENY_RULES,$DENY_EXTRA"

CURRENT_PID=""
CURRENT_TASK=""

mkdir -p "$RUNS"

# ---------- small helpers ----------

now_local() { date '+%d %b %Y %H:%M %Z'; }
say() { printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*"; }
lower() { tr '[:upper:]' '[:lower:]'; }

notify() {
  command -v osascript >/dev/null 2>&1 || return 0
  t=$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  m=$(printf '%s' "$2" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  osascript -e "display notification \"$m\" with title \"$t\"" >/dev/null 2>&1 || true
}

# field FILE NAME: value of the first "NAME: value" line.
field() {
  K="$2" awk 'BEGIN { k = ENVIRON["K"] ":"; n = length(k) }
    substr($0, 1, n) == k { v = substr($0, n + 1); sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v); print v; exit }' "$1"
}

# set_field FILE NAME VALUE: replace the first "NAME:" line, or add one after the title.
set_field() {
  tmp=$(mktemp "$1.XXXXXX") || return 1
  K="$2" V="$3" awk 'BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"]; n = length(k) + 1 }
    { line[NR] = $0; if (!f && substr($0, 1, n) == k ":") f = NR }
    END {
      for (i = 1; i <= NR; i++) {
        if (i == f) print k ": " v; else print line[i]
        if (!f && i == 1) print k ": " v
      }
    }' "$1" > "$tmp" && mv "$tmp" "$1"
}

# add_line FILE TEXT: append a line at the end of the file.
add_line() { printf '%s\n' "$2" >> "$1"; }

# json_get FILE KEY: read one top-level key from Claude Code's JSON result.
json_get() {
  if command -v plutil >/dev/null 2>&1; then
    plutil -extract "$2" raw -o - "$1" 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1 && [ "$(uname)" != "Darwin" ]; then
    python3 - "$1" "$2" <<'PY' 2>/dev/null && return 0
import json, sys
d = json.load(open(sys.argv[1]))
if isinstance(d, list):
    d = [m for m in d if isinstance(m, dict) and m.get("type") == "result"][-1]
v = d.get(sys.argv[2], "")
print(str(v).lower() if isinstance(v, bool) else v)
PY
  fi
  sed -n "s/.*\"$2\" *: *\"\{0,1\}\([^\",}]*\).*/\1/p" "$1" | head -1
}

# log_entry PROJECT DID WAITING TASK: put an entry at the top of log.md.
log_entry() {
  f="$BRIDGE/log.md"
  [ -f "$f" ] || printf '# Claude Code log (newest first)\n' > "$f"
  E=$(printf '## %s · %s (written by the runner)\n- Did: %s\n- Commit / link: none\n- Waiting on owner: %s\n- Task: %s' "$(now_local)" "$1" "$2" "$3" "$4")
  tmp=$(mktemp "$f.XXXXXX") || return 1
  E="$E" awk 'BEGIN { e = ENVIRON["E"]; done = 0 }
    !done && /^## / { print e; print ""; done = 1 }
    { print }
    END { if (!done) { print ""; print e } }' "$f" > "$tmp" && mv "$tmp" "$f"
}

find_claude() {
  if [ -n "${CLAUDE_BIN:-}" ] && [ -x "$CLAUDE_BIN" ]; then echo "$CLAUDE_BIN"; return 0; fi
  c=$(command -v claude 2>/dev/null)
  if [ -n "$c" ]; then echo "$c"; return 0; fi
  for c in "$HOME/.local/bin/claude" "$HOME/.claude/local/claude" /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME/.npm-global/bin/claude" "$HOME"/.nvm/versions/node/*/bin/claude; do
    if [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}

project_dir() {
  [ -f "$SYS/projects.txt" ] || return 1
  d=$(P="$1" awk 'BEGIN { p = ENVIRON["P"] } $1 == p { sub(/^[^ \t]+[ \t]+/, ""); sub(/[ \t\r]+$/, ""); print; exit }' "$SYS/projects.txt")
  [ -n "$d" ] || return 1
  case "$d" in "~"*) d="$HOME${d#\~}" ;; esac
  echo "$d"
}

slug() { printf '%s' "$1" | lower | sed -e 's/[^a-z0-9-]/-/g' -e 's/--*/-/g' | cut -c1-40 | sed 's/-$//'; }

# ---------- GitHub sync ----------

SYNC_WARNED_AT=0
git_on() { [ "$GITHUB_SYNC" = "1" ] && [ -d "$BRIDGE/.git" ] && git -C "$BRIDGE" remote get-url origin >/dev/null 2>&1; }

sync_problem() {
  printf '%s  %s\n' "$(now_local)" "$1" >> "$RUNS/sync.log"
  nowsec=$(date +%s)
  if [ $((nowsec - SYNC_WARNED_AT)) -ge 3600 ]; then
    SYNC_WARNED_AT=$nowsec
    say "GitHub sync problem: $1 (details in _system/runs/sync.log). The bridge keeps working on this Mac."
    notify "Claude bridge" "GitHub sync needs a look: $1"
  fi
}

# Commit this Mac's changes first, then rebase onto GitHub's, then push. A clash
# stops the merge (nothing is lost: this Mac keeps its commit, GitHub keeps its
# own) and is reported; the bridge keeps working on this Mac meanwhile.
sync_all() {
  git_on || return 0
  if [ -n "$(git -C "$BRIDGE" status --porcelain 2>/dev/null)" ]; then
    git -C "$BRIDGE" add -A >/dev/null 2>&1
    git -C "$BRIDGE" commit -q -m "bridge: $(now_local)" >/dev/null 2>&1 || { sync_problem "could not commit on this Mac"; return 0; }
  fi
  if ! GIT_TERMINAL_PROMPT=0 git -C "$BRIDGE" pull --rebase -q >>"$RUNS/sync.log" 2>&1; then
    git -C "$BRIDGE" rebase --abort >/dev/null 2>&1
    sync_problem "could not merge GitHub's changes with this Mac's (both kept; ask Claude Code to merge them)"
    return 0
  fi
  if git -C "$BRIDGE" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    if [ -n "$(git -C "$BRIDGE" log --oneline '@{u}..HEAD' 2>/dev/null)" ]; then
      GIT_TERMINAL_PROMPT=0 git -C "$BRIDGE" push -q >>"$RUNS/sync.log" 2>&1 || sync_problem "could not push to GitHub"
    fi
  else
    GIT_TERMINAL_PROMPT=0 git -C "$BRIDGE" push -q -u origin HEAD >>"$RUNS/sync.log" 2>&1 || sync_problem "could not push to GitHub"
  fi
}

# ---------- one task ----------

run_task() {
  t="$1"
  name=$(basename "$t" .md)
  proj=$(field "$t" Project)
  dir=$(project_dir "$proj")
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    set_field "$t" Status "waiting on owner"
    add_line "$t" "- Runner ($(now_local)): did not start. The project \"$proj\" has no folder in _system/projects.txt, or the folder is missing."
    log_entry "$proj" "Runner could not start $name: no project folder." "add the project's folder to _system/projects.txt" "tasks/$name.md"
    notify "Claude bridge: needs you" "$name: no folder for project $proj"
    say "Skipped $name: no folder for project \"$proj\"."
    return
  fi

  ws=$(field "$t" Workspace | lower)
  model=$(field "$t" Model)
  stamp=$(date '+%Y%m%d-%H%M%S')
  log="$RUNS/$name-$stamp.log"
  out="$RUNS/$name-$stamp.json"

  is_git=0
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && is_git=1

  wt=""
  if [ "$ws" != "main" ] && [ "$is_git" = "1" ]; then
    wt="bridge-$(slug "$name")"
    # Keep Claude's worktrees out of "git status" in the main folder, so deploy
    # scripts that refuse a dirty folder are not upset by them. Local only.
    gd=$(cd "$dir" && cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd)
    if [ -n "$gd" ]; then
      mkdir -p "$gd/info"
      grep -qxF '.claude/worktrees/' "$gd/info/exclude" 2>/dev/null || printf '\n.claude/worktrees/\n' >> "$gd/info/exclude"
    fi
    where="You are in a separate git worktree named $wt, on branch worktree-$wt, made from the project's current commit, so the main folder ($dir) and anyone working there are untouched. If a build needs gitignored folders such as media or sources, link them from the main folder the way this project's docs describe; do not copy large folders."
  else
    where="You are working in the project folder itself ($dir)."
  fi

  prompt="You are running unattended. The claude-bridge runner on the owner's Mac started this session for one task. Nobody is watching and you cannot ask questions mid-way: work the task through, then stop.

Task file: $t
Project: $proj
$where

First read the task file, then ~/Developer/claude-bridge/RULES.md, ~/Developer/claude-bridge/notes/$proj.md (and notes/_all-projects.md), and the project's own owner rules and status files that ~/Developer/claude-bridge/projects.md lists for it.

Do the task as far as you can without the owner. Limits for unattended runs:
- Do not deploy, push to GitHub, merge into the live branch, publish, post, send email or messages, request indexing, or change DNS, accounts or settings outside this computer. Prepare everything up to that point (commits on your branch, a local preview, PDFs or screenshots) and stop there.
- Do not touch uncommitted changes you did not make.
- If something needs the owner's decision, a login, or a permission you do not have, stop and explain it. Do not guess around it.
- Never write passwords, keys, tokens or OTPs into any file.

When you finish or stop:
1. Fill in the Result section of the task file: date, what changed (files, branch, commit), preview link or file paths, checks you ran, and questions for the owner.
2. Change the task file's \"Status:\" line to \"waiting on owner\" if anything needs the owner's OK, a decision or a deploy, or to \"done\" if nothing is left.
3. Add an entry at the top of ~/Developer/claude-bridge/log.md in its usual format.
4. End your reply with one short plain-English paragraph for the owner."

  # The prompt goes straight after -p; the comma-joined deny list goes last.
  set -- -p "$prompt" --output-format json --permission-mode auto --name "bridge: $name" --add-dir "$BRIDGE"
  [ "$HAS_PERMISSION_PROMPTS" = "1" ] && set -- "$@" --permission-prompts none
  [ -n "$wt" ] && set -- "$@" --worktree "$wt" --settings '{"worktree":{"baseRef":"head"}}'
  [ -n "$model" ] && set -- "$@" --model "$model"
  set -- "$@" --disallowedTools "$DENY_RULES"

  set_field "$t" Status "in progress"
  add_line "$t" "- Runner: started $(now_local) (run log: _system/runs/$name-$stamp.log)"
  say "Starting $name in $dir${wt:+ (worktree $wt)}"
  notify "Claude bridge" "Started: $name"
  sync_all

  CURRENT_TASK="$t"
  ( cd "$dir" && exec env -u ANTHROPIC_API_KEY "$CLAUDE" "$@" ) >"$out" 2>"$log" &
  CURRENT_PID=$!
  start=$(date +%s)
  timed_out=0
  while kill -0 "$CURRENT_PID" 2>/dev/null; do
    sleep 5
    if [ $(( $(date +%s) - start )) -ge "$MAX_SECONDS" ]; then
      timed_out=1
      say "Time limit reached for $name; stopping the session."
      kill -INT "$CURRENT_PID" 2>/dev/null
      i=0
      while kill -0 "$CURRENT_PID" 2>/dev/null && [ "$i" -lt 12 ]; do sleep 5; i=$((i + 1)); done
      pkill -TERM -P "$CURRENT_PID" 2>/dev/null
      kill -TERM "$CURRENT_PID" 2>/dev/null
      break
    fi
  done
  wait "$CURRENT_PID" 2>/dev/null
  code=$?
  CURRENT_PID=""
  CURRENT_TASK=""
  mins=$(( ( $(date +%s) - start + 59 ) / 60 ))

  sid=$(json_get "$out" session_id)
  iserr=$(json_get "$out" is_error | lower)
  status=$(field "$t" Status | lower)

  if [ "$timed_out" = "1" ]; then
    outcome="stopped at the $(( MAX_SECONDS / 60 ))-minute limit"
  elif [ "$code" != "0" ] || [ "$iserr" = "true" ]; then
    outcome="ended with an error (exit $code)"
  else
    outcome="finished"
  fi

  if [ "$status" = "in progress" ]; then
    set_field "$t" Status "waiting on owner"
    add_line "$t" "- Runner: the session $outcome without updating this task. See the run log; the session can be continued (below)."
    log_entry "$proj" "Runner: $name $outcome without updating the task." "look at the run log, or continue the session" "tasks/$name.md"
    status="waiting on owner"
  fi

  add_line "$t" "- Runner: $outcome $(now_local) after $mins min (exit $code)."
  if [ -n "$sid" ]; then
    add_line "$t" "- To continue this session in the Claude app, run in Terminal: claude --desktop --resume $sid   (or in Terminal itself: claude --resume $sid)"
  fi

  case "$status" in
    done) notify "Claude bridge: done" "$name" ;;
    *) notify "Claude bridge: needs you" "$name ($status)" ;;
  esac
  say "$name: $outcome; task status is now \"$status\"."
}

# Mark tasks that a previous runner started but never finished (the Mac slept
# through a crash, the window was closed, and so on).
recover_interrupted() {
  for t in "$TASKS"/*.md; do
    [ -f "$t" ] || continue
    [ "$(field "$t" Status | lower)" = "in progress" ] || continue
    last=$(grep -E '^- Runner: ' "$t" | tail -1)
    case "$last" in
      "- Runner: started"*)
        set_field "$t" Status "waiting on owner"
        add_line "$t" "- Runner: this run was interrupted (the runner stopped before it finished). Check the run log, then set Status back to open to run it again."
        say "Marked $(basename "$t") as interrupted."
        ;;
    esac
  done
}

cleanup() {
  trap - INT TERM EXIT
  if [ -n "$CURRENT_PID" ] && kill -0 "$CURRENT_PID" 2>/dev/null; then
    pkill -TERM -P "$CURRENT_PID" 2>/dev/null
    kill -TERM "$CURRENT_PID" 2>/dev/null
    sleep 2
    if [ -n "$CURRENT_TASK" ] && [ -f "$CURRENT_TASK" ]; then
      set_field "$CURRENT_TASK" Status "waiting on owner"
      add_line "$CURRENT_TASK" "- Runner: stopped by hand at $(now_local) while this task was running. Set Status back to open to run it again."
    fi
  fi
  rm -rf "$LOCK"
  say "Runner stopped."
  exit 0
}

# ---------- start ----------

if mkdir "$LOCK" 2>/dev/null; then
  echo $$ > "$LOCK/pid"
else
  old=$(cat "$LOCK/pid" 2>/dev/null)
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
    echo "The Claude bridge runner is already running (process $old). Close that window first if you want to restart it."
    exit 1
  fi
  rm -rf "$LOCK"
  mkdir "$LOCK" && echo $$ > "$LOCK/pid"
fi
trap cleanup INT TERM EXIT

CLAUDE=$(find_claude)
if [ -z "$CLAUDE" ]; then
  echo "Claude Code's command-line tool was not found. Run: bash ~/Developer/claude-bridge/_system/install.sh"
  rm -rf "$LOCK"
  trap - INT TERM EXIT
  exit 1
fi
HAS_PERMISSION_PROMPTS=0
"$CLAUDE" --help 2>/dev/null | grep -q -- '--permission-prompts' && HAS_PERMISSION_PROMPTS=1

# The bridge holds your notes, so the runner only syncs it to a GitHub repo that
# gh confirms is private. See ALLOW_UNVERIFIED_REMOTE in _system/config.sh.
if git_on && [ "${ALLOW_UNVERIFIED_REMOTE:-0}" != "1" ]; then
  url=$(git -C "$BRIDGE" remote get-url origin)
  vis=""
  command -v gh >/dev/null 2>&1 && vis=$(gh repo view "${url%.git}" --json visibility -q .visibility 2>/dev/null)
  if [ "$vis" != "PRIVATE" ]; then
    GITHUB_SYNC=0
    say "GitHub copy is off for this session: could not confirm that $url is a private repo."
  fi
fi

echo
echo "Claude bridge runner"
echo "  Watching: $TASKS (tasks with \"Status: open\" and \"Run: auto\")"
echo "  Claude Code: $CLAUDE ($("$CLAUDE" --version 2>/dev/null | head -1))"
if git_on; then echo "  GitHub copy: $(git -C "$BRIDGE" remote get-url origin)"; else echo "  GitHub copy: off"; fi
echo "  Keep this window open. Ctrl+C stops the runner. To pause, create _system/PAUSE."
echo

recover_interrupted

while :; do
  # Heartbeat, so chat can tell the runner is alive (stays on this Mac).
  printf '%s\n' "$(now_local)" > "$LOCK/heartbeat" 2>/dev/null
  sync_all
  if [ -f "$SYS/PAUSE" ]; then
    [ "${PAUSED_SAID:-0}" = "1" ] || { say "Paused (delete _system/PAUSE to resume)."; PAUSED_SAID=1; }
  else
    PAUSED_SAID=0
    for t in "$TASKS"/*.md; do
      [ -f "$t" ] || continue
      case "$(basename "$t")" in _*) continue ;; esac
      [ "$(field "$t" Status | lower)" = "open" ] || continue
      [ "$(field "$t" Run | lower)" = "auto" ] || continue
      [ -f "$SYS/PAUSE" ] && break
      run_task "$t"
      sync_all
    done
  fi
  [ "${RUN_ONCE:-0}" = "1" ] && break
  sleep "$POLL_SECONDS"
done
