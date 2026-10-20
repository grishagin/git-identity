# git-identity

Switch a repo's git identity (name, email, SSH key and signing key) between profiles you define once, with a single command, for example:

```
git identity personal
```

If you have more than one identity (work and personal, or multiple GitHub accounts), it's easy to commit with the wrong name and email. Once an email is in a pushed commit, it stays in the history for good. This tool lets you set the right identity per repo in one step, and shows at a glance which one a repo is using.

## Requirements

- Windows with [Git for Windows](https://gitforwindows.org/)
- [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) (`pwsh`)

## Install

```powershell
git clone <this repo> D:\tools\git-identity
D:\tools\git-identity\install.ps1
```

The installer adds the folder to your user `PATH` and creates `~/.git-identities.json` from the example. Restart open terminals afterwards.

## Configure

Profiles live in `~/.git-identities.json` (`git identity edit` opens it):

```json
{
  "profiles": {
    "work": {
      "name": "Jane Doe",
      "email": "jane.doe@example.com",
      "sshKey": "~/.ssh/id_ed25519"
    },
    "personal": {
      "name": "janed",
      "email": "janed@example.org",
      "sshKey": "~/.ssh/id_ed25519_personal",
      "signingKey": "~/.ssh/id_ed25519_personal.pub"
    }
  }
}
```

| Field | Required | Sets | Notes |
|---|---|---|---|
| `name` | yes | `user.name` | |
| `email` | yes | `user.email` | |
| `sshKey` | no | `core.sshCommand` | Pushes and pulls authenticate with this key, even when the remote is plain `git@github.com:...`. No SSH host aliases needed. |
| `signingKey` | no | `user.signingkey`, `commit.gpgsign` | A `.pub` path enables SSH signing (`gpg.format ssh`); anything else is used as a GPG key ID. |

Switching profiles also clears the optional settings the new profile doesn't use, so nothing carries over from the previous one.

## Usage

Run inside a repo:

```
git identity                 show the current identity and where it comes from
git identity list            list profiles (* = active here)
git identity <profile>       apply a profile to this repo
git identity <profile> -g    apply a profile globally (~/.gitconfig)
git identity edit            open the profiles file
git identity help            show usage
```

`git-identity.ps1` can also be run directly, for example `git-identity.ps1 list`.

```
> git identity
work  Jane Doe <jane.doe@example.com>  [global]
  This repo has no identity of its own; it inherits the one above.

> git identity personal
Switched local identity to personal (janed <janed@example.org>)
```

## Tip: never commit with the wrong identity

Remove your global name and email, and tell git to refuse commits until an identity has been set:

```
git config --global --unset user.name
git config --global --unset user.email
git config --global user.useConfigOnly true
```

Every new repo then stops at its first commit until you run `git identity <profile>` in it.

## How it works

`git identity` works because git runs any `git-<name>` executable it finds on `PATH` as a subcommand. The `git-identity` file is a two-line shell script that hands the arguments to `git-identity.ps1`. The script only writes ordinary git config values, at `--local` scope or with `-g` at `--global` scope, so you can inspect or undo everything it does with `git config`.
