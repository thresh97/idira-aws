#!/usr/bin/env bash
# Installs CyberArk's AWS CLI tool (patched) with its own venv and an `awslogin` zsh function.
# Safe to re-run: the tool is re-extracted and re-patched, and the existing .venv is kept.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIP="$REPO_DIR/aws-cli-utilities-master.zip"
PATCH_FILE="$REPO_DIR/patches/auth-py-fixes.patch"
TEMPLATE="$REPO_DIR/awslogin.zsh"
TOOL_SUBDIR="aws-cli-utilities-master/AWS CLI - Idaptive V1"

DEST="$HOME/.local/share/cyberark-aws-cli"
TENANT="" REGION="" ROLE="" EDIT_ZSHRC=0

usage() {
  cat <<'EOF'
Usage: ./install.sh --tenant <name|host> --region <aws-region> --role <role-name> [--dest <dir>] [--zshrc]

  --tenant   CyberArk tenant, e.g. "acme" or "acme.id.cyberark.cloud"
  --region   AWS region written to the profile, e.g. us-west-2
  --role     IAM role name you will assume (not the ARN). The tool names the profile "<role>_profile".
  --dest     Install directory (default: ~/.local/share/cyberark-aws-cli)
  --zshrc    Append a `source` line for awslogin to ~/.zshrc (otherwise the line is only printed)

Example:
  ./install.sh --tenant acme --region us-west-2 --role my_admin_role --zshrc
EOF
}

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tenant) TENANT="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    --role)   ROLE="${2:-}"; shift 2 ;;
    --dest)   DEST="${2:-}"; shift 2 ;;
    --zshrc)  EDIT_ZSHRC=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done

[ -n "$TENANT" ] && [ -n "$REGION" ] && [ -n "$ROLE" ] || { usage >&2; die "--tenant, --region and --role are required"; }
for v in "$TENANT" "$REGION" "$ROLE"; do
  [[ "$v" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid value '$v' (allowed: letters, digits, '.', '_', '-')"
done
case "$DEST" in *'|'*|*'&'*|*'\'*) die "--dest must not contain '|', '&' or '\\'" ;; esac

HOST="$TENANT"
case "$HOST" in *.*) ;; *) HOST="$HOST.id.cyberark.cloud" ;; esac

for cmd in python3 unzip patch sed; do
  command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done
python3 -c 'import venv' 2>/dev/null || die "python3 venv module is missing"
command -v aws >/dev/null || echo "warning: AWS CLI ('aws') not found; install it, awslogin uses it to verify credentials" >&2
[ -f "$ZIP" ] && [ -f "$PATCH_FILE" ] && [ -f "$TEMPLATE" ] || die "run from the repo checkout (zip, patches/ and awslogin.zsh must exist)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Extracting original tool"
unzip -q "$ZIP" "$TOOL_SUBDIR/*" -d "$TMP"
mkdir -p "$DEST"
cp -R "$TMP/$TOOL_SUBDIR/." "$DEST/"

echo "==> Applying patch"
patch -p1 -s -d "$DEST" < "$PATCH_FILE"

echo "==> Creating virtualenv and installing dependencies"
[ -x "$DEST/.venv/bin/python" ] || python3 -m venv "$DEST/.venv"
"$DEST/.venv/bin/pip" install --quiet --upgrade boto3 requests colorama
"$DEST/.venv/bin/python" -m py_compile "$DEST/core/auth.py"

echo "==> Writing $DEST/awslogin.zsh"
sed -e '1d' \
    -e "s|<role-name>|$ROLE|g" \
    -e "s|<region>|$REGION|g" \
    -e "s|<tenant>.id.cyberark.cloud|$HOST|g" \
    -e "s|\$HOME/.local/share/cyberark-aws-cli|$DEST|g" \
    "$TEMPLATE" > "$DEST/awslogin.zsh"

SOURCE_LINE="source \"$DEST/awslogin.zsh\""
if [ "$EDIT_ZSHRC" -eq 1 ]; then
  if grep -qsF "$SOURCE_LINE" "$HOME/.zshrc"; then
    echo "==> ~/.zshrc already sources awslogin"
  else
    printf '\n%s\n' "$SOURCE_LINE" >> "$HOME/.zshrc"
    echo "==> Added source line to ~/.zshrc"
  fi
else
  echo "==> Add this line to ~/.zshrc (or re-run with --zshrc):"
  echo "    $SOURCE_LINE"
fi

cat <<EOF

Done. In a new zsh shell (or after sourcing the file) run:  awslogin
It prompts for username, password and MFA (pick Mobile Authenticator, tap the number it prints).
Profile: ${ROLE}_profile   Region: $REGION   Tenant: $HOST
EOF
