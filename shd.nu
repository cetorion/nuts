export def shd [] {
  let drs = [repos code nu]
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
