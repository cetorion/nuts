export def sgr [] {
  gpgconf --kill all | ignore 
  gpgconf --launch gpg-agent | ignore
  $env.SSH_AUTH_SOCK = (gpgconf --list-dirs agent-ssh-socket)
  $env.GPG_TTY = (tty)
  gpg-connect-agent updatestartuptty /bye | ignore
}
