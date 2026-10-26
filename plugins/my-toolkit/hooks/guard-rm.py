#!/usr/bin/env python3
"""PreToolUse-хук на видалення: тимчасові папки — без питань, решта — тільки з дозволу людини.

Кожна підкоманда `rm` (з -r чи без), `unlink`, `find … -delete` / `find … -exec rm` (шляхи find — як
rm -r) у Bash-команді, також за `sudo`/`doas`; шлях рахується від cwd з урахуванням `cd`:
  - усі шляхи строго всередині тимчасової папки (/tmp, $TMPDIR) поза проєктом, або всередині
    «вільної» папки проєкту з .claude/guard-rm.json        → пропустити (без питань);
  - хоч один шлях деінде або його не видно ($, бектики, `cd $X`, `xargs rm`)
                                                           → «ask»: Claude Code питає людину;
  - рекурсивний rm на /, ~, корінь проєкту чи вище, корінь вкладеного git-репо, саму тимчасову
    чи вільну папку                                        → заборона (exit 2), навіть з дозволом.
Кінцевий компонент шляху не розкривається (rm видаляє посилання, а не те, на що воно вказує),
батьківська папка — через realpath. Шаблон (*, ?, [) — дивиться папку до шаблону.
`bash -c '…'` і heredoc у shell розбираються, як у guard-main.py (той самий розбір команди).

Вільні папки проєкту — `<проєкт>/.claude/guard-rm.json`: {"safe_dirs": ["art/drafts"]}, шляхи
відносно кореня проєкту. Запис поза проєктом, сам корінь або битий JSON — ігноруються (вільних папок
менше, не більше). Тимчасові папки для тестів задає GUARD_RM_TEMP_DIRS (через «:»).
Не межа безпеки: скрипти, alias, `perl -e unlink`, `python -c`, `mv` у кошик не розбираються.

Вихід: 2 = заборона (причина в stderr); 0 + JSON permissionDecision "ask" = спитати людину;
0 без виводу = звичайний потік дозволів.
"""
import importlib.util
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.realpath(__file__))
sys.dont_write_bytecode = True  # без __pycache__ у hooks/
_spec = importlib.util.spec_from_file_location("guard_main", os.path.join(HERE, "guard-main.py"))
_gm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_gm)

GLOB = re.compile(r"[*?\[]")
# Обгортки, за якими може стояти rm (guard-main.WRAPPERS їх не знає): sudo/doas — повноваження.
EXTRA_WRAPPERS = {"sudo", "doas", "xcrun"}
# Перший вираз find (-name, !, дужки) — кінець списку шляхів.
FIND_PATH_END = re.compile(r"^(-|!|\(|\))")
CONFIG = os.path.join(".claude", "guard-rm.json")
FREE, ASK, DENY = "free", "ask", "deny"


def project_root(cwd):
    root = os.environ.get("CLAUDE_PROJECT_DIR")
    if root:
        return os.path.realpath(root)
    try:
        out = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        if out.returncode == 0:
            return os.path.realpath(out.stdout.strip())
    except OSError:
        pass
    return None


def temp_dirs():
    """Тимчасові папки: /tmp і $TMPDIR (на macOS це /private/tmp і /private/var/folders/…)."""
    override = os.environ.get("GUARD_RM_TEMP_DIRS")
    raw = override.split(":") if override is not None else ["/tmp", os.environ.get("TMPDIR"), tempfile.gettempdir()]
    out = []
    for d in raw:
        if not d:
            continue
        real = os.path.realpath(os.path.expanduser(d)).rstrip(os.sep) or os.sep
        if real != os.sep and real not in out:
            out.append(real)
    return out


def safe_dirs(root):
    """Вільні папки з <проєкт>/.claude/guard-rm.json — лише строго всередині проєкту."""
    if not root:
        return []
    try:
        with open(os.path.join(root, CONFIG), encoding="utf-8") as f:
            entries = json.load(f).get("safe_dirs") or []
    except (OSError, ValueError, AttributeError):
        return []
    out = []
    for e in entries if isinstance(entries, list) else []:
        if not isinstance(e, str) or not e.strip() or os.path.isabs(e) or e.startswith("~"):
            continue
        real = os.path.realpath(os.path.join(root, e))
        if real.startswith(root + os.sep) and real not in out:
            out.append(real)
    return out


def nested_repos(root):
    """Корені git-репо, вкладених у проєкт першим рівнем (workspace з кількох репо)."""
    if not root:
        return []
    try:
        names = os.listdir(root)
    except OSError:
        return []
    return [os.path.join(root, n) for n in names if os.path.exists(os.path.join(root, n, ".git"))]


def is_recursive(args):
    for a in args:
        if a == "--":
            break
        if a == "--recursive":
            return True
        if a.startswith("-") and not a.startswith("--") and ("r" in a or "R" in a):
            return True
    return False


def paths_of(args):
    out, opts = [], True
    for a in args:
        if opts and a == "--":
            opts = False
        elif opts and a.startswith("-") and a != "-":
            continue
        else:
            out.append(a)
    return out


def inside(path, base):
    return path == base or path.startswith(base.rstrip(os.sep) + os.sep)


class Guard:
    def __init__(self, root):
        self.root = root
        self.temps = temp_dirs()
        self.safe = safe_dirs(root)
        self.repos = nested_repos(root)
        self.home = os.path.realpath(os.path.expanduser("~"))
        self.verdict = FREE
        self.reasons = []

    def note(self, verdict, reason):
        order = {FREE: 0, ASK: 1, DENY: 2}
        if order[verdict] > order[self.verdict]:
            self.verdict = verdict
        self.reasons.append(reason)

    def free(self, path, root_ok=False):
        """Строго всередині вільної папки проєкту (root_ok: сама папка теж — корінь find чи шаблону),
        або строго всередині тимчасової папки й не в проєкті (проєкт чи worktree теж буває в /tmp)."""
        for s in self.safe:
            if path.startswith(s + os.sep) or (root_ok and path == s):
                return True
        if self.root and inside(path, self.root):
            return False
        return any(path.startswith(t + os.sep) for t in self.temps)

    def dangerous(self, target):
        """Рекурсивно видаляти не можна навіть з дозволом: /, ~, корінь проєкту чи вище, вкладене репо,
        сама тимчасова чи вільна папка."""
        if target in ("/", self.home) or target in self.temps or target in self.safe or target in self.repos:
            return True
        if self.root and (target == self.root or self.root.startswith(target.rstrip(os.sep) + os.sep)):
            return True
        return False

    def classify(self, path, dir_, recursive, root_ok=False):
        if "$" in path or "`" in path or dir_ is None:
            self.note(ASK, f"шлях «{path}» не видно до запуску")
            return
        full = os.path.normpath(os.path.join(dir_, os.path.expanduser(path)))
        m = GLOB.search(full)
        if m:
            base = full[:m.start()]
            parent = os.path.realpath(base if base.endswith(os.sep) else os.path.dirname(base) or "/")
            if self.free(parent, root_ok=True):
                return
            # Шаблон просто в /tmp зачепить чужі файли й сокети — питаємо, але не забороняємо.
            if recursive and self.dangerous(parent) and parent not in self.temps:
                self.note(DENY, f"«{path}» — шаблон у {parent}")
            else:
                self.note(ASK, f"«{path}» поза вільними папками")
            return
        name = os.path.basename(full)
        parent = os.path.realpath(os.path.dirname(full) or "/")
        target = os.path.realpath(full) if name in ("", ".", "..") else os.path.join(parent, name)
        if self.free(target, root_ok=root_ok):
            return
        if recursive and self.dangerous(target):
            self.note(DENY, f"«{path}» = {target}")
        else:
            self.note(ASK, f"«{path}» поза вільними папками")

    def check_bash(self, command, cwd):
        command, shell_bodies = _gm.split_heredocs(command)
        for body in shell_bodies:
            self.check_bash(body, cwd)
        try:
            lex = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=True)
            lex.whitespace_split = True
            tokens = list(lex)
        except ValueError:
            self.note(ASK, "не вдалося розібрати команду з rm")
            return

        segments, seg, skip = [], [], False
        for t in tokens:
            if skip:
                skip = False
            elif t in _gm.SEPARATORS:
                segments.append(seg)
                seg = []
            elif set(t) <= set("<>&"):
                skip = True
                # `2>/dev/null`: дескриптор перед редиректом — не аргумент команди.
                if seg and seg[-1].isdigit():
                    seg.pop()
            else:
                seg.append(t)
        segments.append(seg)

        dir_ = cwd
        for seg in segments:
            seg = _gm.strip_prefix(seg)
            if seg and os.path.basename(seg[0]) in EXTRA_WRAPPERS:
                # sudo -u user rm …: опції обгортки мають значення — шукаємо саму команду видалення.
                names = [os.path.basename(a) for a in seg]
                hit = next((i for i, n in enumerate(names) if i > 0 and n in ("rm", "unlink", "find", "xargs")), None)
                seg = _gm.strip_prefix(seg[hit:]) if hit is not None else []
            if not seg:
                continue
            prog = os.path.basename(seg[0])
            if prog == "cd":
                target = seg[1] if len(seg) > 1 else "~"
                if "$" in target or "`" in target or dir_ is None:
                    dir_ = None
                else:
                    dir_ = os.path.normpath(os.path.join(dir_, os.path.expanduser(target)))
            elif prog in _gm.SHELLS and "-c" in seg[:-1]:
                self.check_bash(seg[seg.index("-c") + 1], dir_ or cwd)
            elif prog == "xargs" and "rm" in [os.path.basename(a) for a in seg[1:]]:
                self.note(ASK, "xargs … rm: шляхів не видно")
            elif prog in ("rm", "unlink"):
                rec = prog == "rm" and is_recursive(seg[1:])
                for p in paths_of(seg[1:]):
                    self.classify(p, dir_, rec)
            elif prog == "find" and ("-delete" in seg or any(
                    a in ("-exec", "-execdir", "-ok", "-okdir") and i + 1 < len(seg)
                    and os.path.basename(seg[i + 1]) in ("rm", "unlink") for i, a in enumerate(seg))):
                # find видаляє все під своїми шляхами (до першого виразу): ті шляхи — як у rm -r.
                # Корінь find — сама вільна папка: видаляє лише знахідки під нею.
                roots = []
                for a in seg[1:]:
                    if FIND_PATH_END.match(a):
                        break
                    roots.append(a)
                for p in roots or ["."]:
                    self.classify(p, dir_, True, root_ok=True)


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if data.get("tool_name") != "Bash":
        return
    command = (data.get("tool_input") or {}).get("command", "")
    if not re.search(r"\b(rm|unlink|find)\b", command):
        return
    cwd = data.get("cwd") or os.getcwd()
    g = Guard(project_root(cwd))
    g.check_bash(command, cwd)
    if g.verdict == DENY:
        print("guard-rm: " + "; ".join(r for r in g.reasons) +
              ". Рекурсивно видаляти /, ~, корінь проєкту, вкладене репо, саму тимчасову чи вільну папку не можна.",
              file=sys.stderr)
        sys.exit(2)
    if g.verdict == ASK:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": "guard-rm: видалення поза вільними папками — потрібен дозвіл людини ("
                                        + "; ".join(g.reasons) + ")",
        }}, ensure_ascii=False))


if __name__ == "__main__":
    main()
