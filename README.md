# OneRepo OneKey

English | [简体中文](README.zh-CN.md)

One repo, one key. A CLI tool to create dedicated SSH keys for GitHub repositories, clone repos, and configure per-repository SSH authentication.

Download [orok.sh](orok.sh) to get started. You do not need to clone the repository.

## Usage

Requires Bash 3.2+, Git and OpenSSH. Supports macOS and Linux.

### 1. Simplified usage (orok.sh)

From the directory containing your downloaded `orok.sh`, run it with Bash. No installation or executable permission is required.

With the default directory, skip separate `init` and `key` commands and clone directly:

```bash
bash ./orok.sh clone owner/repo
```

On first use, the default key directory `~/.ssh/one-repo-one-key/github.com/` is created and saved automatically; existing directory settings are respected. If a key is missing, enter Y to create it, add the displayed public key to the GitHub repository's **Settings → Deploy keys**, then return to the terminal and enter Y to continue cloning. Enable write access if you need to push. After cloning, press Enter or Y to save the repository-local key configuration.

From another directory, use the script's actual path, for example `bash "$HOME/Downloads/orok.sh" clone owner/repo`.

### 2. Full usage (orok.sh)

Follow the steps below. Step 1 is needed only once and can be skipped for the default directory. After step 2, add the public key to GitHub's **Settings → Deploy keys** before running step 3. Enable write access if you need to push.

```bash
# 1. Optional: save a key directory once
bash ./orok.sh init ~/.ssh/one-repo-one-key/github.com
# 2. Create a key, then add its public key to GitHub
bash ./orok.sh key owner/repo
# 3. Clone the repository
bash ./orok.sh clone owner/repo
```

### 3. Configure PATH for the global command (orok)

From the directory containing your downloaded `orok.sh`, install it as the current user's `orok` command and configure `PATH` for the current terminal:

```bash
mkdir -p "$HOME/.local/bin"
install -m 755 ./orok.sh "$HOME/.local/bin/orok"
export PATH="$HOME/.local/bin:$PATH"
orok --help
```

To use `orok` from any directory in new terminals, add the following line once to your shell configuration: `~/.zshrc` for zsh or `~/.bashrc` for Bash.

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Save the file and open a new terminal, or load the configuration for your shell:

```bash
# zsh
source ~/.zshrc
# Bash
source ~/.bashrc
```

For Bash login terminals, also ensure `~/.bash_profile` loads `~/.bashrc`. This configures the command search path, `PATH`; no environment variable named `orok` is needed. Install once; after downloading an updated script, run the `install` command again.

### 4. Simplified usage (orok)

After setup, run the command from any directory:

With the default directory, skip separate `init` and `key` commands and clone directly:

```bash
orok clone owner/repo
```

On first use, the default key directory `~/.ssh/one-repo-one-key/github.com/` is created and saved automatically; existing directory settings are respected. If a key is missing, enter Y to create it, add the displayed public key to the GitHub repository's **Settings → Deploy keys**, then return to the terminal and enter Y to continue cloning. Enable write access if you need to push. After cloning, press Enter or Y to save the repository-local key configuration.

### 5. Full usage (orok)

Follow the steps below. Step 1 is needed only once and can be skipped for the default directory. After step 2, add the public key to GitHub's **Settings → Deploy keys** before running step 3. Enable write access if you need to push.

```bash
# 1. Optional: save a key directory once
orok init ~/.ssh/one-repo-one-key/github.com
# 2. Create a key, then add its public key to GitHub
orok key owner/repo
# 3. Clone the repository
orok clone owner/repo
```

### Repository addresses

Both `key` and `clone` accept `owner/repo` or the full SSH URL:

```bash
orok key git@github.com:owner/repo.git
orok clone git@github.com:owner/repo.git
```

The shorthand uses the repository name literally (without adding a `.git` suffix yourself). It is converted to `git@github.com:owner/repo.git` for cloning. Usually, `orok clone owner/repo` is enough: it guides you through creating a missing key.

Add the displayed public key to the repository's **Settings → Deploy keys**. Enable write access if you need to push. When cloning without a key, the script offers to create one and waits for you to confirm registration. After cloning, press Enter or Y to save the key selection in `.git/config` for subsequent Git commands.

### Key directory

Without saved configuration, the first `key` or `clone` creates `~/.ssh/one-repo-one-key/github.com/` and records its absolute path in `${XDG_CONFIG_HOME:-$HOME/.config}/one-repo-one-key/key_dir`. Later commands reuse that record; no environment variables are required. Existing saved directories take precedence.

To save a custom directory, run this once (the supplied directory is used directly):

```bash
orok init /your/key-directory
```

Running `init` again changes the saved directory; it does not move existing keys. To explicitly switch an existing configuration to the new default:

```bash
orok init ~/.ssh/one-repo-one-key/github.com
```

Keys are Ed25519 with no passphrase, stored as `owner__repo` in the initialized directory. The remote URL remains unchanged. Configuration defaults to `${XDG_CONFIG_HOME:-$HOME/.config}/one-repo-one-key`; `ONE_REPO_ONE_KEY_CONFIG_DIR` overrides it.

## Language

Script messages follow the first nonempty value of `LC_ALL`, `LC_MESSAGES`, then `LANG`. Chinese locales (`zh_CN`, `zh_TW`, `zh-Hans`, etc.) select Simplified Chinese; all other or unrecognized values select English. If all three variables are empty on macOS, the first AppleLanguages preference is used. If detection fails, English is used.

```bash
# Force Chinese
LC_ALL= LC_MESSAGES=zh_CN.UTF-8 orok --help
# Force English
LC_ALL=C orok --help
```

Git, SSH and system command output follows those programs' own language settings.
