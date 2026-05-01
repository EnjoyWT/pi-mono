# 同步官方仓库并保留本项目定制

本文档用于当前 fork 的长期维护：官方仓库持续更新，本项目只保留少量定制源码、包名和 GitHub Packages 发布配置。

同步的主要目的不是永久保留所有历史包或所有本地文件，而是让本项目尽量贴近官方最新代码，同时保留明确属于本项目的定制：`@enjoywt/*` 包名、GitHub Packages 发布配置，以及确实需要保留的源码级改动。

## 分支约定

- `upstream/main`：官方仓库 `badlogic/pi-mono`。
- `main`：本地和 fork 中用于跟随官方的分支，不放本项目定制。
- `my-work`：本项目长期定制分支，保留源码微调、包名前缀和发布配置。
- `origin`：自己的 fork `EnjoyWT/pi-mono`。

默认策略是让 `main` 快进到官方最新提交，再把 `main` 合并进 `my-work`。不要把本项目定制直接提交到 `main`。

如果官方删除了旧模块，而本项目只是因为包名替换或版本同步碰过它们的 `package.json`，通常应接受官方删除。不要因为历史上做过包名重写，就把官方已经移除的模块继续留在 `my-work`。

## 同步前检查

先确认工作区干净：

```bash
git status --short --branch
```

如果有未提交改动，先提交到 `my-work`。同步脚本会拒绝在脏工作区运行，避免切分支时覆盖正在编辑的文件。

可以先预演一次：

```bash
.codex/skills/sync-upstream-my-work/scripts/sync-fork.sh --dry-run --push-main
```

`--dry-run` 只打印将要执行的命令，不会修改仓库。

## 推荐同步流程

在仓库根目录运行：

```bash
.codex/skills/sync-upstream-my-work/scripts/sync-fork.sh --push-main
```

脚本会执行：

1. 检查工作区是否干净。
2. 拉取 `upstream`。
3. 切到 `main`。
4. 用 `merge --ff-only upstream/main` 让 `main` 和官方一致。
5. 使用 `--push-main` 时，把更新后的 `main` 推送到 `origin/main`。
6. 切回 `my-work`。
7. 把 `main` 合并进 `my-work`。
8. 校验自定义包名和 GitHub Packages registry 没有被官方配置覆盖。

脚本不会自动推送 `my-work`。同步成功并完成必要验证后，手动推送定制分支：

```bash
git push origin my-work
```

## 必须保留的定制

同步后这些配置必须仍然存在：

- `packages/agent/package.json` 的 `name` 是 `@enjoywt/pi-agent-core`。
- `packages/ai/package.json` 的 `name` 是 `@enjoywt/pi-ai`。
- `packages/coding-agent/package.json` 的 `name` 是 `@enjoywt/pi-coding-agent`。
- 上面三个包的 `publishConfig.registry` 都是 `https://npm.pkg.github.com`。
- `.github/workflows/publish-github-packages.yml` 仍然存在。

可以随时单独运行校验：

```bash
.codex/skills/sync-upstream-my-work/scripts/sync-fork.sh --verify-only
```

## 冲突处理

如果合并 `main` 到 `my-work` 时出现冲突：

1. 只处理冲突文件，不要重置整个仓库。
2. 上游新增的源码、依赖、版本号和功能性修改通常应保留。
3. 本项目的包名、仓库地址、GitHub Packages registry 必须保留。
4. 如果内部依赖版本被上游更新，保留新的版本号，但依赖包名仍要指向对应的 `@enjoywt/*` 包。
5. 如果冲突是官方删除模块、本地只改过包元数据，通常接受官方删除。
6. 冲突解决后显式添加你处理过的文件，例如 `git add packages/ai/package.json`。
7. 继续完成 merge commit。

如果冲突涉及源码或测试文件，提交前运行：

```bash
npm run check
```

### 保留还是删除的判断规则

下次遇到类似冲突时，先根据证据判断，不要反复询问：

必须保留：

- `packages/agent`、`packages/ai`、`packages/coding-agent` 三个包的 `@enjoywt/*` 包名。
- 这三个包的 `publishConfig.registry = https://npm.pkg.github.com`。
- `.github/workflows/publish-github-packages.yml` 等 fork 发布相关配置。
- 明确属于本项目的源码级功能改动，例如队列行为、prompt metadata、submission 相关字段。
- `.codex/skills/sync-upstream-my-work/` 下的同步技能和说明。

通常接受官方变更或删除：

- 官方删除了某个模块，本项目只因为包名替换、版本同步或 lockfile 更新碰过它。
- 官方做了大范围重构、依赖迁移、删除旧模块或更新生成文件，而这些不属于本项目明确的定制功能。
- 保留该文件会把官方已经移除的旧 workspace 重新带回 `my-work`。

判断命令：

```bash
git log --oneline main..HEAD -- <path>
git diff --stat main..HEAD -- <path>
git show --stat --oneline <fork-commit>
```

只有冲突涉及非平凡的本地源码功能，而且无法从提交记录判断意图时，才需要询问用户。像 `mom` / `pods` 这种官方删除模块、本地只残留包元数据改动的情况，直接接受官方删除。

## 是否需要到 GitHub 手动编译包

当前 `.github/workflows/publish-github-packages.yml` 只配置了：

```yaml
on:
  workflow_dispatch:
```

这表示发布包不会在 push 后自动运行。需要发布新包时，要到 GitHub 手动触发 workflow：

1. 先把同步后的 `my-work` 推送到 `origin/my-work`。
2. 打开 GitHub 仓库的 `Actions` 页面。
3. 选择 `Publish GitHub Packages`。
4. 点击 `Run workflow`。
5. 分支选择 `my-work`。
6. 运行 workflow。

不需要在本地手动编译包。这个 workflow 会在 GitHub Actions 中安装依赖、构建 `packages/tui`、`packages/ai`、`packages/agent`、`packages/coding-agent`，然后发布三个 `@enjoywt/*` 包到 GitHub Packages。

只有需要发布新包版本时才触发 workflow。如果只是同步代码但暂时不需要在其他项目中使用新包，可以不运行发布 workflow。

发布前确认三个包的 `version` 大于已发布版本。GitHub Packages 不允许重复发布同一个包版本，版本号未变化时 `npm publish` 会失败。
