# Claude Code -> omp mechanical text mapping (single source of truth).
# Applied by scripts/build-omp.py via `LC_ALL=C sed -E -f omp/translate.sed`
# to translated copies of rules/, skills/**/*.md, local-skills/**/*.md and agents/.
# Never applied to omp/ override/overlay files (those are written omp-native).
#
# Portable ERE (BSD + GNU sed): word boundaries are explicit character classes.
# A boundary char consumed by one match cannot start the next one, so every
# word rule loops (`t <label>`) until no occurrence is left on the line.
# Rules never span lines; the build batches all files into one sed run.

# --- Task tools -> todo (combined form first) ---
:todo_pair
s/(^|[^[:alnum:]_])TaskCreate\/TaskUpdate([^[:alnum:]_]|$)/\1todo\2/
t todo_pair
:todo_create
s/(^|[^[:alnum:]_])TaskCreate([^[:alnum:]_]|$)/\1todo\2/
t todo_create
:todo_update
s/(^|[^[:alnum:]_])TaskUpdate([^[:alnum:]_]|$)/\1todo\2/
t todo_update
:todo_list
s/(^|[^[:alnum:]_])TaskList([^[:alnum:]_]|$)/\1todo\2/
t todo_list
:todo_get
s/(^|[^[:alnum:]_])TaskGet([^[:alnum:]_]|$)/\1todo\2/
t todo_get

# --- Question tool ---
:ask
s/(^|[^[:alnum:]_])AskUserQuestion([^[:alnum:]_]|$)/\1ask\2/
t ask

# --- Background process control ---
:task_stop
s/(^|[^[:alnum:]_])TaskStop([^[:alnum:]_]|$)/\1proc:\/\/<id>\/kill\2/
t task_stop
:kill_shell
s/(^|[^[:alnum:]_])KillShell([^[:alnum:]_]|$)/\1proc:\/\/<id>\/kill\2/
t kill_shell
s/`BashOutput`/`proc:\/\/<id>` \/ `artifact:\/\/<id>`/g
:bash_output
s/(^|[^[:alnum:]_])BashOutput([^[:alnum:]_]|$)/\1proc:\/\/<id> \/ artifact:\/\/<id>\2/
t bash_output

# --- Bash tool parameters (Claude ms timeout -> omp seconds) ---
:bg
s/(^|[^[:alnum:]_])run_in_background: true([^[:alnum:]_]|$)/\1async: true\2/
t bg
:timeout
s/(^|[^[:alnum:]_])timeout: 600000([^[:alnum:]_]|$)/\1timeout: 600\2/
t timeout

# --- Skill arguments: omp passes them in the `User:` line ---
# Only the backticked prose form; bare $ARGUMENTS/$0/$1 in shell code stay.
s/`\$ARGUMENTS`/skill argümanları (`User:` satırı)/g
# Bare $ARGUMENTS in commands: omp does not substitute it; the agent fills it in.
s/\$ARGUMENTS/<argümanlar>/g

# --- Background completion notice (omp auto-delivers async results) ---
s/`task-notification` bekle/sonucu bekle (otomatik gelir)/g
s/`task-notification`/async sonuç bildirimi/g

# --- Skill tool call -> skill:// ---
s/Skill\(skill: "personal-assistant:([a-z0-9-]+)", args: "([^"]*)"\)/read skill:\/\/\1 → argümanlarla uygula: \2/g

# --- Worktree: omp cannot move the session cwd ---
s/`EnterWorktree\(\{ name \}\)`\. Session cwd worktree'ye gecer;/`git worktree add ..\/<repo>-<isim> -b <isim>`; komutlari o dizinde (cwd) calistir, dosya yollarini mutlak ver;/g

# --- Claude user memory dir -> omp memory ---
s/`~\/\.claude\/memory\/`/omp hafızası (memory)/g

# --- Rule file paths -> rule:// (bare ~/.claude/rules/ dir mentions stay) ---
s/~\/\.claude\/rules\/([[:alnum:]_.-]+)\.md/rule:\/\/\1/g

# --- Backticked tool names (bare prose words are left alone) ---
s/`Read`/`read`/g
s/`Write`/`write`/g
s/`Edit`/`edit`/g
s/`Bash`/`bash`/g
s/`Grep`/`grep`/g
s/`Glob`/`glob`/g
s/`WebFetch`/`read`/g
s/`Task`/`task`/g
