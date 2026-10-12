# Copy to ~/.local/share/cyberark-aws-cli/awslogin.zsh, fill in the <placeholders>, and source it from ~/.zshrc.
# Logs in via CyberArk's AWS CLI tool, verifies the credentials, then exports AWS_PROFILE.
awslogin() {
  local profile="${AWSLOGIN_PROFILE:-}"
  local role_name
  if [ -z "$profile" ] && [ -n "${AWSLOGIN_ROLE_ARN:-}" ]; then
    role_name="${AWSLOGIN_ROLE_ARN#*/}"
    profile="${role_name%%/*}_profile"
  fi
  [ -n "$profile" ] || profile="<default-profile>"
  local region="${AWSLOGIN_REGION:-<region>}"
  local dir="$HOME/.local/share/cyberark-aws-cli"
  ( cd "$dir" && .venv/bin/python AWSCLI.py -t <tenant>.id.cyberark.cloud -r "$region" "$@" ) || return
  if [ -z "$profile" ]; then
    echo "awslogin: profile name unknown, so credentials were not verified and AWS_PROFILE was not set." >&2
    echo "Set AWSLOGIN_ROLE_ARN or AWSLOGIN_PROFILE, or run: export AWS_PROFILE=<role-name>_profile" >&2
    return 0
  fi
  aws sts get-caller-identity --profile "$profile" \
    && export AWS_PROFILE="$profile"
}
