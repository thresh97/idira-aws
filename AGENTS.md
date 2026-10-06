# AGENTS.md

Repo for getting local AWS CLI / Terraform credentials through CyberArk Identity SAML federation, using CyberArk's own Python tool plus a small patch and an `awslogin` zsh wrapper. `README.md` is the human walkthrough; this file is for AI agents.

## Layout

| Path | What it is | Edit? |
|---|---|---|
| `aws-cli-utilities-master.zip` | Pristine upstream tool. Single source of truth for the original. | Never |
| `patches/auth-py-fixes.patch` | Our only change to upstream: `core/auth.py`. | Yes, by regenerating (below) |
| `awslogin.zsh` | Template with `<tenant>`, `<region>`, `<role-name>` placeholders. | Yes |
| `install.sh` | Extracts zip, applies patch, builds venv, renders `awslogin.zsh`. Idempotent. | Yes |
| `README.md`, `AGENTS.md` | Docs. | Yes |

The installed copy lives outside the repo (default `~/.local/share/cyberark-aws-cli/`, with its own `.venv`, `aws-cli.log` and a rendered `awslogin.zsh`). Never treat it as source: change the patch, then re-run `install.sh`.

## Hard rules

- **Never run the login.** `awslogin` / `AWSCLI.py` need a password and a phone MFA tap. Ask the user to run it, e.g. `! awslogin` in Claude Code (or `! source <dest>/awslogin.zsh && awslogin`).
- `AWS_PROFILE` exported inside a `!` subshell does not persist. Pass `AWS_PROFILE=<profile>` explicitly on each command.
- Never read, print or copy `~/.aws/credentials`, STS keys/tokens, or SAML assertions into chat, files or commits. `aws-cli.log` can contain session details; grep it narrowly instead of dumping it.
- No personal or account-specific values anywhere in the repo: no tenant names, account IDs, emails, app keys or role ARNs. Use placeholders, or the established fake examples only: tenant `acme`, login username `jdoe` (short name; the email `jdoe@example.com` appears only as the AWS session name), accounts `123456789012` / `210987654321`, roles `my_admin_role` / `my_readonly_role`, region `us-west-2`, app names `AWS Example IDP` / `AWS Example GovCloud`, app keys `00000000-1111-2222-3333-444444444444` / `55555555-6666-7777-8888-999999999999`. Keep examples consistent with these when adding more. Before finishing a change, scan for them: `grep -rIniE '<your-values>' . --exclude='*.zip'`.
- Don't edit `~/.zshrc` or other dotfiles on your own; `install.sh --zshrc` is the user's opt-in.
- Don't use or create long-lived IAM user keys, and don't copy EC2 instance-role credentials to the laptop.
- Don't modify the zip or files extracted from it in place; express changes as patches.

## Workflows

**Change tool behavior (patching `auth.py`)**
1. Extract the original to a scratch dir and apply the current patch: `unzip -q aws-cli-utilities-master.zip -d /tmp/orig && patch -p1 -d "/tmp/orig/aws-cli-utilities-master/AWS CLI - Idaptive V1" < patches/auth-py-fixes.patch`.
2. Keep a pristine second extraction, edit the patched copy, then regenerate with labels so it applies with `-p1`: `diff -u --label a/core/auth.py --label b/core/auth.py <pristine>/core/auth.py <edited>/core/auth.py > patches/auth-py-fixes.patch` (diff exits 1 when files differ; that is expected). If you touch more files, extend the patch and keep `a/` and `b/` path prefixes.
3. Verify: `patch -p1 --dry-run` against a pristine extraction, `python3 -m py_compile` on the result.

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
- Only Mobile Authenticator MFA works (number matching; the patch prints the number). FIDO2/U2F polls forever or fails.
- Picking an app with no IAM roles in its assertion (typically Identity Center) crashes with `IndexError`; harmless, pick another app.
- The tool must run from its own directory (reads `proxy.properties`, writes `aws-cli.log` there); `awslogin` does `cd` in a subshell.
- The tool rewrites `~/.aws/credentials` via `RawConfigParser`: profiles are kept, comments are dropped. The profile is named `<role-name>_profile`.
- Tool dependencies are only `boto3`, `requests`, `colorama`; it targets plain IAM SAML (`sts:AssumeRoleWithSAML`), not IAM Identity Center.
- saml2aws (Browser provider) was tried and is a dead end for now: version 2.36.19 pins Playwright driver 1.47.2, whose download host is retired (404). Don't suggest it again unless a newer release fixes the driver download.

## Style

- Shell: bash 3.2-compatible (macOS), `set -euo pipefail`, validate user input before using it in `sed`.
- Docs: keep README and this file in sync when behavior, flags or file names change. Short, concrete, no account-specific values.
- Default to no code comments unless the reason is non-obvious.
