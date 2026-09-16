# OneRepo OneKey · 一仓一钥

[English](README.md) | 简体中文

为每个 GitHub 仓库创建独立 SSH 密钥，完成仓库克隆与本地密钥绑定。

只需下载 [orok.sh](orok.sh) 即可使用，无需克隆整个仓库。

## 使用

需要 Bash 3.2+、Git 和 OpenSSH，支持 macOS 与 Linux。

### 1. 简化使用（orok.sh）

进入下载的 `orok.sh` 所在目录，先赋予执行权限，再直接运行，无需安装。每次重新下载后，如文件没有执行权限，再执行一次 `chmod +x`。

使用默认目录时，无需单独执行 `init` 或 `key`。从 GitHub 仓库的 **Code → SSH** 复制地址，替换示例中的 `git@github.com:owner/repo.git` 后直接克隆：

```bash
chmod +x ./orok.sh
./orok.sh clone git@github.com:owner/repo.git
# 简写方式（二选一）：
# ./orok.sh clone owner/repo
```

首次使用会自动创建默认密钥目录 `~/.ssh/one-repo-one-key/github.com/` 并保存配置；已有目录配置继续生效。如果密钥不存在，输入 Y 创建，将显示的公钥添加到 GitHub 仓库的 **Settings → Deploy keys**，再返回终端输入 Y 继续克隆。需要推送时开启 Deploy Key 的写权限。克隆完成后按回车或 Y，保存该仓库的本地密钥配置。

从其他目录调用时，使用脚本的实际路径，例如 `"$HOME/Downloads/orok.sh" clone git@github.com:owner/repo.git`。

### 2. 完整使用（orok.sh）

下面按步骤执行。第 1 步只需配置一次；使用默认目录时可以省略。第 2 步完成后，先将公钥添加到 GitHub 的 **Settings → Deploy keys**，再执行第 3 步。需要推送时开启写权限。

```bash
# 赋予执行权限（已设置可跳过）
chmod +x ./orok.sh
# 1. 可选：保存密钥目录（只需一次）
./orok.sh init ~/.ssh/one-repo-one-key/github.com
# 2. 创建密钥，并将公钥添加到 GitHub
./orok.sh key git@github.com:owner/repo.git
# 简写方式（二选一）：
# ./orok.sh key owner/repo
# 3. 克隆仓库
./orok.sh clone git@github.com:owner/repo.git
# 简写方式（二选一）：
# ./orok.sh clone owner/repo
```

### 3. 配置环境变量，使用全局命令（orok）

进入下载的 `orok.sh` 所在目录，执行以下命令，将脚本安装为当前用户的 `orok` 命令，并为当前终端配置 `PATH`：

```bash
mkdir -p "$HOME/.local/bin"
install -m 755 ./orok.sh "$HOME/.local/bin/orok"
export PATH="$HOME/.local/bin:$PATH"
orok --help
```

要让新终端也能在任意目录使用 `orok`，将下面这行添加到当前 Shell 的配置文件一次：zsh 使用 `~/.zshrc`，Bash 使用 `~/.bashrc`。

```bash
export PATH="$HOME/.local/bin:$PATH"
```

保存后重新打开终端，或按所用 Shell 加载配置：

```bash
# zsh
source ~/.zshrc
# Bash
source ~/.bashrc
```

`install -m 755` 会同时为安装后的 `orok` 设置执行权限。

Bash 登录终端还需确保 `~/.bash_profile` 会加载 `~/.bashrc`。这里配置的是命令搜索路径 `PATH`，无需定义名为 `orok` 的环境变量。安装只需一次；更新脚本后，重新执行上面的 `install` 命令即可。

### 4. 简化使用（orok）

配置完成后，可以在任意目录执行：

使用默认目录时，无需单独执行 `init` 或 `key`。从 GitHub 仓库的 **Code → SSH** 复制地址，替换示例中的 `git@github.com:owner/repo.git` 后直接克隆：

```bash
orok clone git@github.com:owner/repo.git
# 简写方式（二选一）：
# orok clone owner/repo
```

首次使用会自动创建默认密钥目录 `~/.ssh/one-repo-one-key/github.com/` 并保存配置；已有目录配置继续生效。如果密钥不存在，输入 Y 创建，将显示的公钥添加到 GitHub 仓库的 **Settings → Deploy keys**，再返回终端输入 Y 继续克隆。需要推送时开启 Deploy Key 的写权限。克隆完成后按回车或 Y，保存该仓库的本地密钥配置。

### 5. 完整使用（orok）

下面按步骤执行。第 1 步只需配置一次；使用默认目录时可以省略。第 2 步完成后，先将公钥添加到 GitHub 的 **Settings → Deploy keys**，再执行第 3 步。需要推送时开启写权限。

```bash
# 1. 可选：保存密钥目录（只需一次）
orok init ~/.ssh/one-repo-one-key/github.com
# 2. 创建密钥，并将公钥添加到 GitHub
orok key git@github.com:owner/repo.git
# 简写方式（二选一）：
# orok key owner/repo
# 3. 克隆仓库
orok clone git@github.com:owner/repo.git
# 简写方式（二选一）：
# orok clone owner/repo
```

### 仓库地址

`key` 和 `clone` 都可以直接使用从 GitHub 复制的完整 SSH 地址，也支持注释中的 `owner/repo` 简写（`owner` 为所有者，`repo` 为仓库名）。两种写法任选其一即可：

```bash
orok key git@github.com:owner/repo.git
# 简写方式（二选一）：
# orok key owner/repo
orok clone git@github.com:owner/repo.git
# 简写方式（二选一）：
# orok clone owner/repo
```

简写中的仓库名按原样解析，无需额外添加 `.git`；克隆时会转换为 `git@github.com:owner/repo.git`。直接执行 `clone` 即可在缺少密钥时引导创建。

将显示的公钥添加到仓库的 **Settings → Deploy keys**；需要推送时开启写权限。克隆时若密钥不存在，脚本会询问是否创建，并等待你确认已配置。克隆完成后按回车或 Y，将密钥配置保存至 `.git/config`，后续可直接使用普通 Git 命令。

### 选择 N 后，如何关联密钥

克隆完成后，如果选择 N 跳过保存密钥路径，本次克隆仍已使用专用密钥；后续 `git pull` / `git push` 不会自动使用它，将按默认 SSH 配置进行认证。本地 `git commit` 不受影响。

脚本会显示包含实际仓库路径和密钥路径的命令，复制执行即可完成关联。以下为默认密钥目录下的示例，请替换仓库路径及 `owner/repo` 对应的名称：

```bash
cd /path/to/repo
git config --local core.sshCommand "ssh -i '$HOME/.ssh/one-repo-one-key/github.com/owner__repo' -o IdentitiesOnly=yes"
```

关联后可直接使用 `git pull` / `git push`。此操作仅将密钥路径和 SSH 选项写入仓库的 `.git/config`，不会复制密钥文件或写入私钥内容。推送前，请确认 GitHub 仓库 **Settings → Deploy keys** 中的密钥已开启 **Allow write access**。

### 密钥目录

没有已保存配置时，首次运行 `key` 或 `clone` 会自动创建 `~/.ssh/one-repo-one-key/github.com/`，将绝对路径记录到 `${XDG_CONFIG_HOME:-$HOME/.config}/one-repo-one-key/key_dir`。后续自动读取，无需设置环境变量。已有目录配置优先使用。

自定义目录只需执行一次，密钥直接保存在指定目录内：

```bash
orok init /your/key-directory
```

再次执行 `init` 会更新目录记录，不会移动已有密钥。已有配置如需切换至新默认目录，执行：

```bash
orok init ~/.ssh/one-repo-one-key/github.com
```

密钥使用无密码的 Ed25519，按 `owner__repo` 命名，保存到初始化时指定的目录。远程 URL 保持不变。配置默认保存在 `${XDG_CONFIG_HOME:-$HOME/.config}/one-repo-one-key`，可通过 `ONE_REPO_ONE_KEY_CONFIG_DIR` 指定其他位置。

## 语言

脚本提示依次读取 `LC_ALL`、`LC_MESSAGES`、`LANG`，采用第一个非空值。中文区域设置（如 `zh_CN`、`zh_TW`、`zh-Hans`）统一显示简体中文；其他语言或无法识别的值显示英文。macOS 上三个变量均为空时，读取 AppleLanguages 的第一首选语言；读取失败则默认英文。

```bash
# 强制中文
LC_ALL= LC_MESSAGES=zh_CN.UTF-8 orok --help
# 强制英文
LC_ALL=C orok --help
```

Git、SSH 和系统命令自身的输出由各程序决定，不由脚本翻译。
