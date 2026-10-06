# AWS CLI / Terraform credentials on macOS via CyberArk Identity (SAML)

Get temporary AWS STS credentials into a named profile so plain `aws` and `terraform` work locally when AWS access is federated through a CyberArk Identity (Idira/Idaptive) app tile.

This applies when clicking the AWS tile lands on `https://signin.aws.amazon.com/saml` (plain IAM SAML federation). If you land on an IAM Identity Center portal instead, use `aws configure sso`; none of this applies.

## Quick start

Requirements: macOS with zsh, Python 3 (with `venv`), `unzip`, `patch`, and the [AWS CLI](https://aws.amazon.com/cli/).

```bash
./install.sh --tenant <tenant> --region <aws-region> --role <role-name> --zshrc
```

- `--tenant`: your CyberArk tenant, `acme` or the full host `acme.id.cyberark.cloud`.
- `--region`: AWS region written to the profile, e.g. `us-west-2`.
- `--role`: the IAM role **name** you assume (not the ARN), e.g. `my_admin_role`. The tool names the profile `<role-name>_profile`.
- `--zshrc`: append the `source` line to `~/.zshrc`. Omit it to have the line printed instead.
- `--dest <dir>`: install somewhere other than `~/.local/share/cyberark-aws-cli`.

Example with made-up values (substitute yours):

```bash
./install.sh --tenant acme --region us-west-2 --role my_admin_role --zshrc
```

Then open a new terminal and run `awslogin`.

### Where to find your values

| Value | Example (fake) | Where to look |
|---|---|---|
| Tenant | `acme` (`acme.id.cyberark.cloud`) | The host in the URL when you log in to the CyberArk app portal. |
| Role name | `my_admin_role` | The part after `role/` in the ARN the tool lists at the role prompt, e.g. `arn:aws:iam::123456789012:role/my_admin_role`. |
| Region | `us-west-2` | Wherever you normally work in AWS. It only sets the profile's default region; it doesn't affect the login. |
| AWS app | `AWS Example IDP` | The tile in the app portal that opens `signin.aws.amazon.com/saml`. The tool lists every AWS-type app you have. |
| Username | `jdoe` | Your CyberArk login name as entered at the prompt. Here it is the short username, not the email/UPN. Only if the short name is rejected, try the full email. |

Not sure of the role name? Run the tool once with any `--role`, read the ARN list at the role prompt, then re-run `install.sh` with the right name, or set `AWSLOGIN_PROFILE` later.

## Using awslogin

1. Enter your short username (not the email/UPN), then your password.
2. Pick **Mobile Authenticator** and tap the number printed as `>>> Select this number on your phone: NN`. Security-key mechanisms (FIDO2/U2F) are not supported by this tool.
3. Pick the **IAM SAML** AWS app. An app whose assertion has no IAM roles (typically an Identity Center app) crashes with `IndexError: list index out of range`; just pick a different app.
4. Pick your role. The tool re-prompts after each success; enter `q` to exit.

`awslogin` then runs `aws sts get-caller-identity` and, if that succeeds, exports `AWS_PROFILE=<role-name>_profile` in your shell. Credentials last one hour; run `awslogin` again to refresh.

### Example session (made-up values)

```text
% awslogin
Logfile - aws-cli.log
Please enter your username : jdoe
Password :
1 : Mobile Authenticator
2 : FIDO2 Security Key
3 : U2FONDEVICE
Please choose the mechanism : 1

>>> Select this number on your phone: 42

Waiting for completing authentication mechanism..
Select the aws app to login. Type 'quit' or 'q' to exit
1 : AWS Example IDP | 00000000-1111-2222-3333-444444444444
2 : AWS Example GovCloud | 55555555-6666-7777-8888-999999999999
Enter Number : 1
Select a role to login. Choose one role at a time. ...
[ 1 ]:  arn:aws:iam::123456789012:role/my_admin_role
[ 2 ]:  arn:aws:iam::123456789012:role/my_readonly_role
[ 3 ]:  arn:aws:iam::210987654321:role/my_admin_role
Please select : 1
Your profile is created. It will expire at 2030-01-01 12:00:00+00:00
Use --profile my_admin_role_profile for the commands
Please select : q
Enter Number : q
{
    "UserId": "AROAEXAMPLEEXAMPLEXX:jdoe@example.com",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/my_admin_role/jdoe@example.com"
}
```

Role names can repeat across accounts (here `my_admin_role` exists in two). The profile is named after the role only, so picking the same role name in a different account overwrites the previous profile. Choose the ARN for the account you want.

Overrides (environment variables): `AWSLOGIN_PROFILE`, `AWSLOGIN_REGION`. Extra arguments are passed to the tool, e.g. `awslogin -d` for debug output.

### Using the profile

```bash
aws s3 ls --profile <role-name>_profile
AWS_PROFILE=<role-name>_profile terraform plan
```

Terraform's AWS provider picks up `AWS_PROFILE` (or `profile = "..."` in the provider block) and reads `~/.aws/credentials`. Role chaining via `assume_role` in a provider block caps sessions at one hour regardless of other settings.

## What is in this repo

| Path | Purpose |
|---|---|
| `aws-cli-utilities-master.zip` | CyberArk's original, unmodified `aws-cli-utilities` (Apache-2.0, see `LICENSE.md` inside). Docs: https://identity-developer.cyberark.com/docs/aws-cli |
| `patches/auth-py-fixes.patch` | Fixes for `core/auth.py` against current CyberArk responses (see below). Only `auth.py` differs from the original. |
| `awslogin.zsh` | Template for the `awslogin` shell function; `install.sh` fills in the placeholders. |
| `install.sh` | Extracts the zip, applies the patch, creates a venv with `boto3 requests colorama`, writes `awslogin.zsh`. Safe to re-run. |
| `AGENTS.md` | Guidance for AI coding agents working in this repo. |

### The patch

The 2022 code breaks against the current API in two ways:

1. **MFA menu crash (`KeyError: 'PromptSelectMech'`).** Some mechanisms (e.g. `U2FONDEVICE`) have no `PromptSelectMech`, and the menu loop iterates every key of the challenge dict. The patch iterates only `challenge['Mechanisms']` and labels entries with `PromptSelectMech`, falling back to `Name`, then `AnswerType`.
2. **Number matching is never shown.** Mobile Authenticator with `OTPWITHNUMBER: True` returns `Result.GeneratedAuthValue` from the start-OOB call, but the tool polls silently, so you can't tell which number to tap. The patch prints it.

## Manual install (what `install.sh` does)

```bash
DEST="$HOME/.local/share/cyberark-aws-cli"
unzip -q aws-cli-utilities-master.zip "aws-cli-utilities-master/AWS CLI - Idaptive V1/*" -d /tmp/cyberark-aws
mkdir -p "$DEST" && cp -R "/tmp/cyberark-aws/aws-cli-utilities-master/AWS CLI - Idaptive V1/." "$DEST/"
patch -p1 -d "$DEST" < patches/auth-py-fixes.patch
python3 -m venv "$DEST/.venv" && "$DEST/.venv/bin/pip" install boto3 requests colorama
```

Then copy `awslogin.zsh` to `$DEST/`, replace `<tenant>`, `<region>` and `<role-name>`, and `source` it from `~/.zshrc`. The tool must run from its own directory (it reads `proxy.properties` and writes `aws-cli.log` there), which the function handles with `cd`.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `KeyError: 'PromptSelectMech'` | Unpatched `auth.py`. Re-run `install.sh`. |
| MFA hangs on "Waiting for completing authentication mechanism" | You chose a security-key option. Ctrl-C, re-run, pick Mobile Authenticator. |
| No number shown for Mobile Authenticator | Unpatched `auth.py`. Re-run `install.sh`. |
| `IndexError: list index out of range` at role selection | That app has no IAM roles in its assertion (likely Identity Center). Pick another app. |
| `Access Denied` from `AssumeRoleWithSAML` | The role isn't trusted for your SAML provider or you picked the wrong role. Check the ARN list. |
| `aws: [ERROR]: The config profile (...) could not be found` right after a failed login | Harmless. The tool exits 0 on failure, so the follow-up check ran anyway. |
| Expired credentials | They last one hour. Run `awslogin` again. |
| Wrong profile name | The tool names it `<role>_profile` from the role you picked. Set `AWSLOGIN_PROFILE`. |

## Security notes

- Don't commit or paste STS credentials. They live only in `~/.aws/credentials`, and `aws-cli.log` (git-ignored) can contain session details.
- The tool rewrites `~/.aws/credentials` through a config parser: existing profiles are kept, comments are dropped.
- Don't copy EC2 instance-role credentials to a laptop (GuardDuty flags it as credential exfiltration), and don't create long-lived IAM user keys for this.
- Longer sessions need an admin to raise the role's `MaxSessionDuration` and the `SessionDuration` SAML attribute.

## Uninstall

```bash
rm -rf ~/.local/share/cyberark-aws-cli
# remove the `source .../awslogin.zsh` line from ~/.zshrc
# remove the [<role-name>_profile] section from ~/.aws/credentials
```
