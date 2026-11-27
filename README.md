# AnchorStructor

把散在多个仓库里的子项目当成一个大项目来开发：**仓库各自独立（该开源的继续开源，该私有的保持私有），但装进同一个 Python 环境，跨库一律 `import`，不写路径。**

## 为什么不是一个仓库

子库开源/闭源不同，必须各自独立的 Git 仓库与可见性；monorepo 会把这件事锁死。真正让 `import` 生效的不是「放在同一个目录」，而是「装进同一个解释器环境」——目录在哪、隔多远都无关。

## 目录

```
AnchorStructor/              ← 本仓库：只放清单与脚本，不放子库代码
├── members.public.toml      公开成员（可随仓库公开）
├── members.toml             清单索引
├── requirements-dev.txt    公开成员的 -e 安装清单
├── bootstrap.sh            公开成员的 clone + venv + 安装 + 验证
├── templates/               每库要加的 pyproject 示例
├── .gitignore
└── <各子库>/                 各自独立的仓库，不嵌套进本仓库
```

**私有成员不在本仓库里**：私有库的名字、URL、安装路径只写在本地的 `members.private.toml` / `requirements.private.txt` / `bootstrap.private.sh`，三者都已进 `.gitignore`，不随仓库提交。

## 用法

```bash
./bootstrap.sh              # 公开成员：clone + venv + pip install -e + 验证
./bootstrap.private.sh      # 私有成员（本地文件，不入库）
. .venv/bin/activate
python -c "import multi_agent, alert"     # 任意目录都能 import
```

## 公开成员

| 仓库 | role | import 名 |
|---|---|---|
| multi-agent | library | `multi_agent` |
| options_utility | library | `alert` `calc` `calc.cn` `option_pcr` `cli` … |
| techAnly-summary | library | `charts` `topology` `chanlun.multiscale.chanlun_backtest` |
| stock-dashboard | app | 部署工程（自带 setup.py） |
| anchor-lite | site | HTML 站点，不参与 Python 打包 |

明细见 `members.public.toml`。

## 归属声明

每个子库在自己的 `pyproject.toml` 里写一条，不靠仓库改名：

```toml
[project.urls]
"AnchorStructor" = "https://github.com/baizhiwei9/AnchorStructor"
```

运行时也能读到：

```python
from importlib.metadata import metadata
metadata("multi-agent-hub").get_all("Project-URL")
```

## 三种打包形态

| 形态 | 用在 | 写法 |
|---|---|---|
| 包目录 | 有 `pkg/__init__.py` | `[tool.setuptools.packages.find] include = ["pkg*"]` |
| 扁平模块 | 根目录一排 `.py` | `[tool.setuptools] py-modules = [...]` |
| 隐式命名空间 | 顶层无 `__init__.py`（如 `chanlun/`） | `find` + `namespaces = true` |

## 验证记录（2026-11-27）

7 个 library 装进同一 `.venv` 后，从 `/tmp` 用 `find_spec` 查 15 个 import 名：**15/15 命中**，全部指向各自仓库源码，没有一份来自其它副本。