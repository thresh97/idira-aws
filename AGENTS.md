# AGENTS.md

Repo for getting local AWS CLI / Terraform credentials through CyberArk Identity SAML federation, using CyberArk's own Python tool plus a small patch and an `awslogin` zsh wrapper. `README.md` is the human walkthrough; this file is for AI agents.

## Layout

| Path | What it is | Edit? |
|---|---|---|
| `aws-cli-utilities-master.zip` | Pristine upstream tool. Single source of truth for the original. | Never |
| `patches/*.patch` | Our changes to upstream, applied in the order listed in `install.sh` (`change-notices.patch` last). | Yes, by regenerating (below) |
| `awslogin.zsh` | Template with `<tenant>`, `<region>`, `<role-name>` placeholders. | Yes |
| `install.sh` | Extracts zip, applies patches, builds venv, renders `awslogin.zsh`. Idempotent. | Yes |
| `README.md`, `AGENTS.md` | Docs. | Yes |
| `LICENSE` | MIT, for our original files only. | Rarely |
| `NOTICE.md` | Apache-2.0 attribution for the bundled CyberArk code, modification statement, trademark disclaimer. | When the set of patched files changes |

The installed copy lives outside the repo (default `~/.local/share/cyberark-aws-cli/`, with its own `.venv`, `aws-cli.log` and a rendered `awslogin.zsh`). Never treat it as source: change the patch, then re-run `install.sh`.

## Hard rules

- **Never run the login.** `awslogin` / `AWSCLI.py` need a password and a phone MFA tap. Ask the user to run it, e.g. `! awslogin` in Claude Code (or `! source <dest>/awslogin.zsh && awslogin`).
- `AWS_PROFILE` exported inside a `!` subshell does not persist. Pass `AWS_PROFILE=<profile>` explicitly on each command.
- Never read, print or copy `~/.aws/credentials`, STS keys/tokens, or SAML assertions into chat, files or commits. `aws-cli.log` can contain session details; grep it narrowly instead of dumping it.
- No personal or account-specific values anywhere in the repo: no tenant names, account IDs, emails, app keys or role ARNs. Use placeholders, or the established fake examples only: tenant `acme`, login username `jdoe` (short name; the email `jdoe@example.com` appears only as the AWS session name), accounts `123456789012` / `210987654321`, roles `my_admin_role` / `my_readonly_role`, region `us-west-2`, app names `AWS Example IDP` / `AWS Example GovCloud`, app keys `00000000-1111-2222-3333-444444444444` / `55555555-6666-7777-8888-999999999999`. Keep examples consistent with these when adding more. Before finishing a change, scan for them: `grep -rIniE '<your-values>' . --exclude='*.zip'`.
- Don't edit `~/.zshrc` or other dotfiles on your own; `install.sh --zshrc` is the user's opt-in.
- Don't use or create long-lived IAM user keys, and don't copy EC2 instance-role credentials to the laptop.
- Don't modify the zip or files extracted from it in place; express changes as patches.
- Licensing (Apache-2.0, upstream): every upstream file a patch modifies must carry a prominent change notice in the patched file (see the `NOTICE:` comments added by `change-notices.patch`), and `NOTICE.md` must stay accurate. Never strip upstream copyright headers. Don't use CyberArk/Idaptive/Idira names to imply endorsement.
- Keep the "Unsupported community example" banner at the top of `README.md` and the "Support status" section in `NOTICE.md`. Don't add wording that implies official status, support, SLAs, or endorsement by any company (including the user's employer), and don't name the employer anywhere in the repo.
- Don't document the user's tenant policies (MFA method lists, app lists, org structure); describe only what this tool does.

## Workflows

**Change tool behavior (patching upstream files)**
1. Extract the original to a scratch dir and apply every patch in `install.sh` order: `unzip -q aws-cli-utilities-master.zip -d /tmp/orig`, then `patch -p1 -d "/tmp/orig/aws-cli-utilities-master/AWS CLI - Idaptive V1" < patches/<name>.patch` for each.
2. Keep a copy of the state before your change, edit the patched copy, then regenerate with labels so it applies with `-p1`: `diff -u --label a/<file> --label b/<file> <before>/<file> <edited>/<file> > patches/<name>.patch` (diff exits 1 when files differ; that is expected). Keep `a/` and `b/` path prefixes. New patches go in `install.sh` before `change-notices.patch`.
3. Every upstream file any patch touches needs a `NOTICE:` change notice in its header. `change-notices.patch` carries them; if you modify a new file or change behavior, regenerate it last and update its description.
4. Verify: apply the whole chain to a pristine extraction, `python3 -m py_compile` on the result. Then re-run `install.sh` (with `--dest`) and sync the user's working install so it matches what `install.sh` would produce.

**Test the installer without touching the user's real install**
```bash
./install.sh --tenant testco --region us-west-2 --role test_role --dest /tmp/x
zsh -n /tmp/x/awslogin.zsh && bash -n install.sh
rm -rf /tmp/x
```
Always pass `--dest` when testing; the default destination is the user's working install.

**Verify credentials after the user logs in:** `AWS_PROFILE=<role>_profile aws sts get-caller-identity` (and e.g. `aws ec2 describe-instances --region <region>`).

## Known behavior and gotchas

- The tool exits 0 on failure; judge success by `aws sts get-caller-identity`, not exit codes. That is why `awslogin` chains the check before exporting `AWS_PROFILE`.
- Credentials expire after one hour. The tool doesn't set `DurationSeconds`.
- Only Mobile Authenticator MFA works (number matching; the patch prints the number). Other methods poll forever or fail.
- Picking an app with no IAM roles in its assertion (typically Identity Center) prints a message and returns to the app menu; pick another app.
- The tool must run from its own directory (reads `proxy.properties`, writes `aws-cli.log` there); `awslogin` does `cd` in a subshell.
- The tool rewrites `~/.aws/credentials` via `RawConfigParser`: profiles are kept, comments are dropped. The profile is named `<role-name>_profile`.
- Tool dependencies are only `boto3`, `requests`, `colorama`; it targets plain IAM SAML (`sts:AssumeRoleWithSAML`), not IAM Identity Center.
- saml2aws (Browser provider) was tried and is a dead end for now: version 2.36.19 pins Playwright driver 1.47.2, whose download host is retired (404). Don't suggest it again unless a newer release fixes the driver download.

## Future work

The backlog (Linux/bash portability, `~/.aws` creation and permissions, account-aware profile names, one-pass login, CI) lives in the README under "Future work / TODO". When you complete an item, remove it there and update README, `install.sh --help` and this file together. Linux (including WSL) is untested: don't claim it works until it has been run there. Treat WSL as Linux, and keep the scripts LF-only and bash 3.2-compatible so both macOS and WSL work.

## Style

- Shell: bash 3.2-compatible (macOS), `set -euo pipefail`, validate user input before using it in `sed`.
- Docs: keep README and this file in sync when behavior, flags or file names change. Short, concrete, no account-specific values.
- Default to no code comments unless the reason is non-obvious.
