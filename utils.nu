# Use GPG with SSH 
export def --env sgr [] {
  gpgconf --kill all | ignore 
  gpgconf --launch gpg-agent | ignore
  
  $env.SSH_AUTH_SOCK = (gpgconf --list-dirs agent-ssh-socket)
  $env.GPG_TTY = (tty)

  gpg-connect-agent updatestartuptty /bye | ignore
}

# Link host dirs to home
export def lud [] {
  let drs = [repos code nuts]
  let hst = "/data/host"

  for d in $drs {
    let src = ($hst | path join $d)
    let dst = ($env.home | path join $d)
    
    if not ($src | path exists) { continue }
    
    if ($dst | path exists) {
      print $"info: path exists ($dst)"
    } else {
      print $"info: linking ($src)"
      ln -s $src $dst
    } 
  }
}
