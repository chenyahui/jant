# 个人 fork 分支工作流

本流程适用于 `chenyahui/jant`。`origin` 指向个人 fork，`upstream` 指向
`https://github.com/jant-me/jant.git`。

fork 专用规则统一放在本文档中。上游的指令文件（`AGENTS.md` 和 `CONTRIBUTING.md`）保持不变，
以减少同步冲突。在此 fork 中开始工作时，通过 GitHub 链接引用本文档。

| 分支                         | 用途                     | 允许的更新方式                    |
| ---------------------------- | ------------------------ | --------------------------------- |
| `main`                       | 镜像官方项目             | 仅从 `upstream/main` 快进更新     |
| `my-release`                 | 集成 fork 中已完成的工作 | 通过合并提交纳入工作分支或 `main` |
| `feat/*`、`fix/*`、`chore/*` | 开发和验证改动           | 开发提交                          |

所有开发工作都在工作分支上完成，包括文档、修复和集成冲突处理。不要把 fork 的改动合入 `main`。
不要在 `my-release` 上创建独立提交，也不要使用压缩合并（Squash and merge）或变基合并（Rebase and merge）。

## 开始工作

```bash
git fetch origin
git switch my-release
git merge --ff-only origin/my-release
git switch -c feat/my-feature
```

修复使用 `fix/<name>`，维护使用 `chore/<name>`。准备贡献给官方项目的分支可以从 `main` 创建；
其上游 PR 应提交到 `jant-me/jant`，而不是 fork 的 `main`。

## 集成已完成的工作

在工作分支上运行 `AGENTS.md` 要求的检查，然后推送分支，创建以 `my-release` 为目标的 PR。
合并时选择 **Create a merge commit**。创建 PR 前，先在工作分支上合入目标分支的最新改动：

```bash
git fetch origin
git switch feat/my-feature
git merge origin/my-release
# 在此分支解决冲突、提交，并运行要求的检查。
git push -u origin feat/my-feature
```

如果准备合并期间 `my-release` 有了新提交，回到工作分支，合入更新后的目标分支并重新验证。
不要直接在 `my-release` 上修改文件来解决功能集成冲突。

## 同步官方项目

通过 GitHub 的 **Sync fork** 操作或命令行同步远程 fork，再快进更新本地镜像：

```bash
gh repo sync chenyahui/jant --branch main
git fetch upstream
git switch main
git merge --ff-only upstream/main
```

如果同步或快进更新失败，停下来检查分支为何分叉。不要创建合并提交、把 fork 的改动变基到 `main`，
也不要用强制推送掩盖分叉。

通过集成分支把同步后的 `main` 合入 `my-release`，让冲突处理和验证都在工作分支上完成：

```bash
git fetch origin
git switch my-release
git merge --ff-only origin/my-release
git switch -c chore/sync-upstream-YYYY-MM-DD
git merge main
# 解决冲突，按需提交，并运行要求的检查。
git push -u origin chore/sync-upstream-YYYY-MM-DD
```

按上文「集成已完成的工作」流程，将该分支合入 `my-release`。

## 规则适用范围

本文档定义 fork 的分支约定，GitHub 分支保护则由仓库设置单独控制。目前已启用以下保护：

- `main`：锁定分支，允许从 `jant-me/jant` 同步 fork。
- `my-release`：要求通过 PR 合并，管理员同样受限，禁止强制推送和删除分支。仅允许合并提交。
  此 fork 由一人维护，不要求额外的审核人批准。

`main` 使用经典分支保护规则，并启用 fork 同步。`my-release` 使用已启用的
[PR-only 规则集](https://github.com/chenyahui/jant/settings/rules/26936942)，没有可绕过规则的用户或应用。
两个分支都禁止直接推送；`main` 通过 fork 同步流程更新，`my-release` 通过 PR 集成改动。

上游的贡献指南和包发布说明仍描述官方项目的流程。在此 fork 中，本地工作以 `my-release` 为目标分支。
创建这个分支不会改变默认分支或包发布配置。个人镜像由下文的独立 workflow 构建和发布。

## 发布镜像和测试环境

`.github/workflows/docker-my-release.yml` 在 `chenyahui/jant` 的 `my-release` 分支更新时自动运行。
服务器架构为 x86_64，因此只构建 `linux/amd64` 镜像。流程先运行现有的 Docker Compose 启动检查，通过后发布镜像。
镜像发布后，流程自动部署到 [Jant 测试环境](https://jant.cyhone.com)，并检查 HTTPS 就绪状态。
登录 GHCR 使用 GitHub 自动提供的 `GITHUB_TOKEN`，无需额外配置 Docker Hub 密钥。

镜像名为 `ghcr.io/chenyahui/jant-my-release`，每次发布两个标签：

- `latest`：指向最近发布的构建。
- `v20261116-abc1234`：提交日期加提交号前七位。日期按北京时间计算，同一提交重跑时标签保持一致。

首次发布后，GHCR 包默认为私有。自动部署通过 SSH 标准输入传递本次任务的临时 `GITHUB_TOKEN`，
服务器仅在拉取期间使用它，随后删除临时登录配置。如需匿名拉取，可在包设置中将可见性改为 Public。
详见 [GitHub Container registry 文档](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)。

使用仓库中的 Compose 配置时，在 `.env` 中设置镜像：

```dotenv
IMAGE=ghcr.io/chenyahui/jant-my-release:latest
```

然后拉取并启动：

```bash
mise run docker-pull
mise run docker-up
```

这组命令用于自行运行仓库中的通用 Compose 配置。测试服务器使用下文的独立配置。
需要固定版本时，可将 `latest` 替换为对应的日期与提交号标签。回退前先确认数据库兼容性；
如果新版本已迁移数据库，可能还需要恢复升级前的数据备份。

workflow 也声明了 `workflow_dispatch`，但 GitHub 要求默认分支中存在该 workflow 才能手动触发。
当前 `main` 保持上游镜像，因此默认依靠合入 `my-release` 后自动构建；失败时可在 Actions 中重跑。
参见 [GitHub 手动运行 workflow 的要求](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)。

### 测试服务器

测试环境位于 `193.112.18.149`，域名 `jant.cyhone.com` 的 A 记录指向该地址。
Caddy 处理 HTTPS 和证书续期，Jant 容器只监听服务器的 `127.0.0.1:3000`。

GitHub Environment `jant-test` 只允许 `my-release` 分支部署，包含：

| 类型     | 名称                 | 用途                                |
| -------- | -------------------- | ----------------------------------- |
| Secret   | `DEPLOY_SSH_KEY`     | 专用部署私钥                        |
| Secret   | `DEPLOY_KNOWN_HOSTS` | 经已有 SSH 连接核验的服务器主机公钥 |
| Variable | `DEPLOY_HOST`        | 测试服务器地址                      |

部署公钥在服务器的 `authorized_keys` 中使用 `restrict` 和固定命令，不能开启交互式终端、转发端口或执行任意命令。
入口只接受 `ghcr.io/chenyahui/jant-my-release@sha256:…`，部署本次任务产出的镜像摘要。

服务器配置的源文件位于 `scripts/my-release/`，由管理员安装为 root 所有：

| 源文件         | 服务器路径                         |
| -------------- | ---------------------------------- |
| `compose.yml`  | `/opt/jant-test/compose.yml`       |
| `Caddyfile`    | `/etc/caddy/Caddyfile`             |
| `ssh-entry.sh` | `/usr/local/bin/jant-test-ssh`     |
| `deploy.sh`    | `/usr/local/sbin/jant-test-deploy` |

修改这些文件后，需要通过管理员 SSH 会话更新对应服务器文件；受限部署密钥不能修改部署脚本。
站点配置在 `/opt/jant-test/.env`，数据库和媒体在 `/opt/jant-test/data/`，部署记录在 `/opt/jant-test/current-image`。
更新前先拉取镜像，再暂停写入，把配置和数据一同备份到 `/opt/jant-test/backups/`，然后迁移并启动。
备份包含密钥，仅 root 可读；当前不自动删除备份，需要按磁盘使用情况另行清理。

首次部署在公开服务启动前创建管理员，初始登录信息保存在服务器的 `/home/jant/jant-test-credentials.txt`，
仅 `jant` 用户和 root 可读。站点启用 `NOINDEX=true`，避免测试内容被搜索引擎收录。
