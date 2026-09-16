#!/usr/bin/env bash
# OneRepo OneKey · 一仓一钥
# Dedicated SSH keys and local Git authentication for each GitHub repository.
set -euo pipefail

CONFIG_DIR="${ONE_REPO_ONE_KEY_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/one-repo-one-key}"
KEY_DIR_FILE="$CONFIG_DIR/key_dir"
DEFAULT_KEY_DIR="$HOME/.ssh/one-repo-one-key/github.com"

# Follow locale precedence. On macOS, consult system preferences only if unset.
locale_name="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
if [[ -z "$locale_name" && "$(uname -s)" == Darwin ]]; then
  locale_name="$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2{s/^[[:space:]"]*//;s/[",[:space:]]*$//;p;}' || true)"
fi
UI_LANGUAGE=en
case "$locale_name" in
  zh|zh_*|zh-*|zh.*|zh@*|ZH|ZH_*|ZH-*) UI_LANGUAGE=zh ;;
esac

# Keep each translation next to its English equivalent (Bash 3.2 compatible).
say() {
  local english="$1" chinese="$2"
  shift 2
  if [[ "$UI_LANGUAGE" == zh ]]; then
    printf "$chinese" "$@"
  else
    printf "$english" "$@"
  fi
}

usage() {
  local command_name="${0##*/}"
  if [[ "$command_name" == orok.sh ]]; then
    command_name="$(cd -- "$(dirname -- "$0")" && pwd -P)/$command_name"
  fi
  say 'OneRepo OneKey — dedicated SSH keys for GitHub repositories.\n\n' 'OneRepo OneKey · 一仓一钥 — 为 GitHub 仓库配置独立 SSH 密钥。\n\n'
  say 'Quick clone:\n' '快速克隆：\n'
  printf '  %s clone git@github.com:owner/repo.git\n' "$command_name"
  say '  # Shorthand alternative (choose one):\n' '  # 简写方式（二选一）：\n'
  printf '  # %s clone owner/repo\n\n' "$command_name"
  say 'Usage:\n' '用法：\n'
  printf '  %s init <key-directory>\n  %s key <owner/repo | git@github.com:owner/repo.git>\n  %s clone <owner/repo | git@github.com:owner/repo.git>\n' "$command_name" "$command_name" "$command_name"
  say 'Without saved configuration, keys default to ~/.ssh/one-repo-one-key/github.com/; init is optional.\n' '未保存配置时，密钥默认保存在 ~/.ssh/one-repo-one-key/github.com/；无需先执行 init。\n'
  say '\nExamples:\n' '\n示例：\n'
  printf '  %s init ~/.ssh/one-repo-one-key/github.com\n  %s key git@github.com:owner/repo.git\n  %s clone git@github.com:owner/repo.git\n' "$command_name" "$command_name" "$command_name"
}

die() {
  say 'Error: ' '错误：' >&2
  say "$@" >&2
  printf '\n' >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die 'Command not found: %s' '找不到命令：%s' "$1"
}

ask_yes_no() {
  local answer
  while true; do
    say "$@"
    printf '[Y/N] '
    IFS= read -r answer || die 'Unable to read input' '无法读取输入'
    case "$answer" in
      y|Y|yes|YES|Yes) return 0 ;;
      n|N|no|NO|No) return 1 ;;
      *) say 'Please enter Y or N.\n' '请输入 Y 或 N。\n' ;;
    esac
  done
}

parse_url() {
  local url="$1"
  if [[ "$url" =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ ]]; then
    url="git@github.com:$url.git"
  fi
  if [[ ! "$url" =~ ^git@github\.com:([A-Za-z0-9_-]+)/([A-Za-z0-9_.-]+)\.git$ ]]; then
    die 'Use owner/repo or a GitHub SSH URL: git@github.com:owner/repo.git' '请输入 owner/repo 或 GitHub SSH 地址：git@github.com:所有者/仓库.git'
  fi
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  [[ "$REPO" != . && "$REPO" != .. ]] || die 'Invalid repository name' '仓库名称无效'
  KEY_NAME="${OWNER}__${REPO}"
}

load_key_dir() {
  if [[ ! -e "$KEY_DIR_FILE" ]]; then
    init_key_dir "$DEFAULT_KEY_DIR"
  fi
  IFS= read -r KEY_DIR < "$KEY_DIR_FILE"
  [[ -n "$KEY_DIR" && -d "$KEY_DIR" ]] || die 'The configured key directory does not exist. Run init again.' '初始化的密钥目录不存在，请重新执行 init'
}

show_public_key() {
  local public_key="$1"
  say '\nPublic key:\n\n' '\n公钥：\n\n'
  cat "$public_key"
  printf '\n'
  if command -v pbcopy >/dev/null 2>&1 && pbcopy < "$public_key"; then
    say 'Public key copied to clipboard.\n' '公钥已复制到剪贴板。\n'
  fi
  say 'Add it at: https://github.com/%s/%s/settings/keys\n' '请添加到：https://github.com/%s/%s/settings/keys\n' "$OWNER" "$REPO"
}

init_key_dir() {
  [[ $# -eq 1 ]] || die 'init requires a key directory' 'init 需要指定一个密钥目录'
  local key_dir="$1"
  mkdir -p "$key_dir" "$CONFIG_DIR"
  key_dir="$(cd "$key_dir" && pwd -P)"
  chmod 700 "$key_dir" "$CONFIG_DIR"
  printf '%s\n' "$key_dir" > "$KEY_DIR_FILE"
  chmod 600 "$KEY_DIR_FILE"
  say 'Initialized.\nKey directory: %s\nConfiguration: %s\n' '初始化完成。\n密钥目录：%s\n配置记录：%s\n' "$key_dir" "$KEY_DIR_FILE"
}

create_key() {
  [[ $# -eq 1 ]] || die 'key requires owner/repo or a GitHub SSH URL' 'key 需要 owner/repo 或 GitHub SSH 地址'
  need_command ssh-keygen
  parse_url "$1"
  load_key_dir
  local key_path="$KEY_DIR/$KEY_NAME"
  local public_key="$key_path.pub"
  if [[ -f "$key_path" && -f "$public_key" ]]; then
    say 'Key already exists: %s\n' '密钥已经存在：%s\n' "$key_path"
    show_public_key "$public_key"
    return
  fi
  [[ ! -e "$key_path" && ! -e "$public_key" ]] || die 'Incomplete key files found. Inspect: %s' '发现不完整的同名密钥文件，请人工检查：%s' "$key_path"
  # Each repository has its own Deploy Key; no passphrase for ordinary Git use.
  ssh-keygen -q -t ed25519 -N '' -C "deploy-key:$OWNER/$REPO" -f "$key_path"
  chmod 600 "$key_path"
  chmod 644 "$public_key"
  say 'Key created: %s\n' '密钥创建完成：%s\n' "$key_path"
  show_public_key "$public_key"
}

clone_repo() {
  [[ $# -eq 1 ]] || die 'clone requires owner/repo or a GitHub SSH URL' 'clone 需要 owner/repo 或 GitHub SSH 地址'
  need_command git
  parse_url "$1"
  load_key_dir
  local url="git@github.com:$OWNER/$REPO.git"
  local key_path="$KEY_DIR/$KEY_NAME"
  local repo_dir="$PWD/$REPO"
  # POSIX shell quoting also handles spaces and apostrophes in key paths.
  local escaped_quote="'\\''"
  local quoted_key="${key_path//\'/$escaped_quote}"
  local ssh_command="ssh -i '$quoted_key' -o IdentitiesOnly=yes"
  if [[ ! -f "$key_path" ]]; then
    if ! ask_yes_no 'No key exists for this repository. Create one now? ' '这个项目还没有创建 Key，是否现在创建？'; then
      say 'Clone cancelled.\n' '已取消 clone。\n'
      return
    fi
    create_key "$url"
    say '\nConfigure the Deploy Key at:\n' '\n请前往以下地址配置 Deploy Key：\n'
    printf 'https://github.com/%s/%s/settings/keys\n\n' "$OWNER" "$REPO"
    while ! ask_yes_no 'Have you configured the Deploy Key? ' '您是否已在项目里配置？'; do
      say 'Configure it first, then select Y:\n' '请先完成配置，再选择 Y：\n'
      printf 'https://github.com/%s/%s/settings/keys\n' "$OWNER" "$REPO"
    done
  fi
  GIT_SSH_COMMAND="$ssh_command" git clone "$url"
  local answer
  say "\nOnly the key path and SSH options will be saved in this repository's .git/config. No key files or private key contents will be copied.\n\n" '\n仅将密钥路径和 SSH 选项保存到此仓库的 .git/config，不会复制密钥文件或写入私钥内容。\n\n'
  say 'Remember the dedicated SSH key path for this repository? [Y/n] ' '是否为此仓库记住专用 SSH 密钥的路径？[Y/n] '
  IFS= read -r answer || answer=n
  case "$answer" in
    ''|y|Y|yes|YES|Yes)
      (cd "$repo_dir" && git config --local core.sshCommand "$ssh_command")
      say 'Saved to: %s/.git/config\n' '已写入：%s/.git/config\n' "$repo_dir"
      say 'Remote URL: %s\n' '远程地址：%s\n' "$url"
      ;;
    *)
      say '\nKey path not saved. This clone used the dedicated key, but future pulls or pushes will not automatically use it. Local git commit is unaffected.\n' '\n已跳过保存密钥路径。本次克隆已使用专用密钥，但后续拉取或推送不会自动使用它。本地 git commit 不受影响。\n'
      say '\nTo associate the key later and use ordinary git pull / git push, run:\n' '\n如需以后直接使用 git pull / git push，请执行以下命令关联专用密钥：\n'
      printf 'cd %q\n' "$repo_dir"
      printf 'git config --local core.sshCommand %q\n' "$ssh_command"
      say '\nThis saves only the key path and SSH options; it does not copy key files or private key contents.\n' '\n此操作仅保存密钥路径和 SSH 选项，不会复制密钥文件或写入私钥内容。\n'
      say 'Before pushing, enable Allow write access for the Deploy Key on GitHub:\n' '推送前，请确认 GitHub 仓库的 Deploy Key 已开启 Allow write access：\n'
      printf 'https://github.com/%s/%s/settings/keys\n' "$OWNER" "$REPO"
      ;;
  esac
  say 'Enter repository: ' '进入项目：'
  printf 'cd %q\n' "$repo_dir"
}

main() {
  [[ $# -ge 1 ]] || { usage; exit 1; }
  local command="$1"
  shift
  case "$command" in
    init) init_key_dir "$@" ;;
    key) create_key "$@" ;;
    clone) clone_repo "$@" ;;
    -h|--help|help) usage ;;
    *) usage; die 'Unknown command: %s' '未知命令：%s' "$command" ;;
  esac
}
main "$@"
