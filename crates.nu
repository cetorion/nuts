export def shoot [m: string = "deus", c: string = "devbox"] {
  if (podman machine inspect $m | from json | get State).0 != "running" {
    print $"info: start ($m)"
    if (podman machine start -q $m | complete | get exit_code) != 0 {
      print $"error: start ($m)"
      exit 1
    }
  }

  if (podman container exists $c | complete | get exit_code) != 0 {
    print $"error: void ($c)"
    exit 1 
  }

  if (podman container inspect $c | from json | get State | get Running.0) {
    podman attach $c
    if $env.LAST_EXIT_CODE != 0 {
      print $"error: attach ($c)"
      exit 1
    }
  } else {
    podman start -a $c
    if $env.LAST_EXIT_CODE != 0 {
      print $"error: attach ($c)"
      exit 1
    }
  }
}
