#!/usr/bin/env bash
# ============================================================
# install-system.sh —— 不用 venv：把成员库装进「当前这个 python」
#
# 适合：系统 python 直接 `python xxx.py`、crontab 里写 `$PYTHON_BIN xxx.py` 的用法。
# 装一次即可；之后脚本里不写 sys.path / PYTHONPATH，跨库直接 import。
#
# 用法：
#   ./install-system.sh                 # 装进 PATH 里的 python3
#   PYTHON=/usr/bin/python3 ./install-system.sh
#   ./install-system.sh --user          # 装到 ~/.local（没有 root 时）
#
# crontab 侧：把那行里的 python 指向这个解释器（或保持 /usr/bin/python3 不变），
# 命令本身不用改。
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

PYTHON="${PYTHON:-python3}"
PIP_ARGS=(install)
USE_USER=0
for arg in "$@"; do
  case "$arg" in
    --user) USE_USER=1 ;;
    *) echo "未知参数：$arg（只支持 --user）" >&2; exit 2 ;;
  esac
done
[ "$USE_USER" = "1" ] && PIP_ARGS+=(--user)

if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "找不到解释器：$PYTHON（用 PYTHON=/path/to/python3 指定）" >&2
  exit 1
fi
echo "== 解释器：$("$PYTHON" -c 'import sys; print(sys.executable)')"
echo "== 版本：$("$PYTHON" -V 2>&1)"

# ---- 成员目录：公开成员固定三个；私有成员从本地 members.private.toml 里取 ----
REPOS=(multi-agent options_utility techAnly-summary)
if [ -f members.private.toml ]; then
  while IFS= read -r repo; do
    [ -n "$repo" ] && REPOS+=("$repo")
  done < <(sed -n 's/^[[:space:]]*repo[[:space:]]*=[[:space:]]*"[^"]*\/\([^"]*\)".*/\1/p' members.private.toml)
fi

INSTALLED=()
for repo in "${REPOS[@]}"; do
  if [ ! -d "$ROOT/$repo" ]; then
    echo "-- 跳过 $repo（目录不存在；需要就先 clone 到 $ROOT/$repo）"
    continue
  fi
  if [ ! -f "$ROOT/$repo/pyproject.toml" ] && [ ! -f "$ROOT/$repo/setup.py" ]; then
    echo "-- 跳过 $repo（没有 pyproject.toml / setup.py，不是可安装的库）"
    continue
  fi
  echo "== 安装 $repo"
  "$PYTHON" -m pip "${PIP_ARGS[@]}" -e "$ROOT/$repo"
  INSTALLED+=("$repo")
done

if [ "${#INSTALLED[@]}" -eq 0 ]; then
  echo "没有可安装的成员；先把仓库 clone 到 $ROOT/ 下（如 ./bootstrap.sh 只 clone 不建 venv 也可以手工 git clone）" >&2
  exit 1
fi

# ---- 验证：从 /tmp 导入，证明与当前目录无关 ----
echo "== 验证：从 /tmp 直接 import"
cd /tmp
"$PYTHON" - <<'PY'
import importlib.util as u
names = ["multi_agent", "alert", "calc", "option_pcr", "cli", "charts", "topology"]
bad = []
for name in names:
    spec = u.find_spec(name)
    print(f"  {name:<18} {'OK' if spec else 'MISSING'}")
    if not spec:
        bad.append(name)
print(f"{len(names) - len(bad)}/{len(names)} 可用")
raise SystemExit(1 if bad else 0)
PY

echo
echo "装好了。之后："
echo "  $PYTHON /任意目录/xxx.py        # 直接跑，不用 activate / PYTHONPATH"
echo "crontab 里用同一个解释器即可（写成绝对路径最稳）。"
