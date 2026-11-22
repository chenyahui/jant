# 个人 fork 分支工作流

本流程适用于 `chenyahui/jant`。`origin` 指向个人 fork，`upstream` 指向
`https://github.com/jant-me/jant.git`。

fork 专用规则统一放在本文档中。上游的指令文件（`AGENTS.md` 和 `CONTRIBUTING.md`）保持不变，
以减少同步冲突。在此 fork 中开始工作时，通过 GitHub 链接引用本文档。

| 分支                         | 用途                     | 允许的更新方式                    |
| ---------------------------- | ------------------------ | --------------------------------- |
| `main`                       | 镜像官方项目             | 仅从 `upstream/main` 快进更新     |
| `my-release`                 | 集成 fork 中已完成的工作 | 直接提交，或合入工作分支和 `main` |
| `feat/*`、`fix/*`、`chore/*` | 开发和验证改动           | 开发提交                          |

工作分支用于独立开发、验证和处理集成冲突。不要把 fork 的改动合入 `main`。

## 开始工作

预计贡献给上游的改动，从最新的 `upstream/main` 开工作分支。个人 fork 使用 `my-release` 集成改动。
工作分支按用途命名：特性使用 `feat/<name>`，修复使用 `fix/<name>`，维护使用 `chore/<name>`。

### 贡献给上游

```bash
git fetch upstream
git switch -c feat/my-feature upstream/main
```

在 `feat/my-feature` 开发并验证，将该分支推送到个人 fork，向 `jant-me/jant` 的 `main` 提 PR。
特性改动都提交到这个分支，保持上游 PR 只包含本次改动。

同一个工作目录切换分支时，Git 忽略的本地配置（如 `packages/core/.dev.vars` 和
`packages/core/.env.node`）会保留。需要独立目录时，可以用
`mise run draft feat/my-feature upstream/main` 创建 worktree，代替上面的 `git switch`。
这个任务会复制已有的 `.dev.vars`。如果使用 Node 运行时，在新目录单独准备 `.env.node`。

需要用 `my-release` 的 Docker 配置验证时，从远端的 `my-release` 开集成分支，再合入特性分支：

```bash
git fetch origin
git switch -c chore/integrate-my-feature origin/my-release
git merge feat/my-feature
```

在集成分支上处理与个人配置有关的冲突，并用现有 Docker 流程验证。需要修正特性时，
先在 `feat/my-feature` 提交，再合入集成分支复测。

如果需要提前部署到个人环境，按下文的集成流程把集成分支合入 `my-release`。
如果可以等上游合入，按「同步官方项目」的流程把已合入的特性带回 `my-release`。

### 只用于个人 fork

```bash
git fetch origin
git switch my-release
git merge --ff-only origin/my-release
```

可以在 `my-release` 上直接提交并推送，也可以用 `git switch -c chore/my-fork-change` 创建工作分支。

## 集成已完成的工作

可以在本地将工作分支合入 `my-release` 后直接推送，也可以向 `my-release` 提 PR。
先合入 `origin/my-release` 的最新改动，再运行 `AGENTS.md` 要求的检查。
以下以在本地合入个人 fork 的工作分支为例：

```bash
git fetch origin
git switch chore/my-fork-change
git merge origin/my-release
# 在此分支解决冲突、提交，并运行要求的检查。
git switch my-release
git merge --ff-only origin/my-release
git merge --no-ff chore/my-fork-change
git push origin my-release
```

如果从 GitHub 合并 PR，选择 **Create a merge commit**。如果准备合并期间 `my-release` 有了新提交，
回到工作分支，合入更新后的目标分支并重新验证。

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
# 解决冲突，按需提交。
```

按上文「集成已完成的工作」流程，将该分支合入 `my-release`。

## 规则适用范围

GitHub 锁定了 `main`，并允许从 `jant-me/jant` 同步 fork。`my-release` 的
[分支规则集](https://github.com/chenyahui/jant/settings/rules/26936942)已停用，可以直接推送。

## 发布镜像和测试环境

### 在本机发布

确认 `docker buildx version` 可用。Apple 芯片的 Mac 需要在 Docker 虚拟机中启用 x86_64 模拟。
在当前终端导出 `TCR_USERNAME` 和 `TCR_PASSWORD`，切换到 `my-release` 后执行：

```bash
git switch my-release
make deploy
```

macOS 上，如果已配置 `jant-release`，且当前 Docker context 是 `default`、`colima` 或 `colima-jant-release`，`make deploy` 会使用专用的发布虚拟机。
命令会启动并在结束后关闭本次启动的虚拟机。已设置 `DOCKER_CONTEXT` 或 `DOCKER_HOST` 时，使用指定的 Docker 环境。

`make deploy` 检查当前分支为 `my-release`，然后执行 `git pull --ff-only origin my-release`。拉取失败时停止发布。
拉取成功后，命令用环境变量登录 TCR，从更新后的本地提交构建一次镜像，推送版本标签和 `latest`。
工作目录中未提交的改动不会打进镜像。本机发布跳过测试和 Docker Compose 冒烟检查。

镜像推送后，命令用本机默认 SSH 身份登录下文所列服务器的 `jant` 用户，按本次推送返回的摘要更新测试站，再检查 HTTPS 就绪状态。
发布前确认本机的 `known_hosts` 已信任服务器的 IP 地址，且 `jant` 用户可以用 `sudo -n` 运行 `/usr/local/sbin/jant-test-deploy`。

### 在 GitHub Actions 发布

合入 `my-release` 后，准备部署时用 GitHub CLI 手动启动发布：

```bash
gh workflow run docker-my-release.yml --repo chenyahui/jant --ref my-release
```

工作流构建触发时 `my-release` 的最新提交。合并或推送分支不会触发发布。
服务器架构为 x86_64，因此只构建 `linux/amd64` 镜像。流程先运行现有的 Docker Compose 启动检查，通过后发布镜像。
镜像发布后，流程自动部署到 [Jant 测试环境](https://jant.cyhone.com)，并检查 HTTPS 就绪状态。
工作流使用仓库级 Actions Secrets `TCR_USERNAME` 和 `TCR_PASSWORD` 登录腾讯云 TCR 个人版。
`TCR_USERNAME` 填腾讯云「登录实例」显示的账号 ID，`TCR_PASSWORD` 填该账号的镜像仓库登录密码。

镜像名为 `ccr.ccs.tencentyun.com/chenyahui/jant-my-release`，每次发布两个标签：

- `latest`：指向最近发布的构建。
- `v20261116-abc1234`：提交日期加提交号前七位。日期按北京时间计算，同一提交重跑时标签保持一致。

TCR 仓库为私有仓库。自动部署通过 SSH 标准输入传递 Docker 登录凭证，服务器将凭证保存在临时 Docker 配置中，任务退出时删除该配置。
有权拉取该仓库的用户可运行 `docker login ccr.ccs.tencentyun.com` 登录，详见 [TCR 个人版快速入门](https://cloud.tencent.com/document/product/1141/63910)。

使用仓库中的 Compose 配置时，在 `.env` 中设置镜像：

```dotenv
IMAGE=ccr.ccs.tencentyun.com/chenyahui/jant-my-release:latest
```

然后拉取并启动：

```bash
mise run docker-pull
mise run docker-up
```

这组命令用于自行运行仓库中的通用 Compose 配置。测试服务器使用下文的独立配置。
需要固定版本时，可将 `latest` 替换为对应的日期与提交号标签。回退前先确认数据库兼容性；
如果新版本已迁移数据库，可能还需要恢复升级前的数据备份。

发布失败时，可以在 GitHub Actions 重跑同一次发布。

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
入口只接受 `ccr.ccs.tencentyun.com/chenyahui/jant-my-release@sha256:…`，部署本次任务产出的镜像摘要。

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
