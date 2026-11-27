#!/usr/bin/env bash
# AnchorStructor 公开成员引导：clone → 建同一个 venv → pip install -e → 验证 import
# 私有成员不走这里：见本地 bootstrap.private.sh（不入库）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
OWNER="${ANCHORSTRUCTOR_OWNER:-baizhiwei9}"

REPOS=(multi-agent options_utility techAnly-summary)

for repo in "${REPOS[@]}"; do
  if [ -d "$repo/.git" ]; then
    echo "== 更新 $repo"
    git -C "$repo" pull --ff-only || echo "!! $repo 更新失败（网络或分叉），继续"
  else
    echo "== clone $repo"
    gh repo clone "$OWNER/$repo" "$repo" -- --depth 1 \
      || git clone "git@github.com:$OWNER/$repo.git" "$repo" --depth 1
  fi
done

if [ ! -x .venv/bin/python ]; then
  echo "== 建 venv（优先 virtualenv：部分系统 python3 -m venv 缺 ensurepip）"
  python3 -m virtualenv .venv 2>/dev/null || python3 -m venv .venv
fi
. .venv/bin/activate
python -m pip install -U pip -q
echo "== 安装公开成员（可编辑模式）"
pip install -r requirements-dev.txt "$@"

echo "== 验证：从 /tmp 里 import，证明不依赖当前目录"
cd /tmp
python - <<'PY'
import importlib.util
names = ["multi_agent", "alert", "calc", "option_pcr", "cli", "charts", "topology"]
ok = 0
for name in names:
    spec = importlib.util.find_spec(name)
    ok += bool(spec)
    print(f"  {name:<24} {'OK' if spec else 'MISSING'}")
print(f"{ok}/{len(names)} 可用")
PY

if [ -f "$ROOT/bootstrap.private.sh" ]; then
  echo "== 检测到本地私有清单，可继续运行：$ROOT/bootstrap.private.sh"
fi