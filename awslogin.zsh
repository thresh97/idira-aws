# Copy to ~/.local/share/cyberark-aws-cli/awslogin.zsh, fill in the <placeholders>, and source it from ~/.zshrc.
# Logs in via CyberArk's AWS CLI tool, verifies the credentials, then exports AWS_PROFILE.
awslogin() {
  local profile="${AWSLOGIN_PROFILE:-<role-name>_profile}"
  local region="${AWSLOGIN_REGION:-<region>}"
  local dir="$HOME/.local/share/cyberark-aws-cli"
  ( cd "$dir" && .venv/bin/python AWSCLI.py -t <tenant>.id.cyberark.cloud -r "$region" "$@" ) \
    && aws sts get-caller-identity --profile "$profile" \
    && export AWS_PROFILE="$profile"
}
