# Const defaults
const base = 'certs'
const conf = {
  ca: ca
  sm: sm
  cad: 3650
  smd: 730
  key: key.pem
  crt: crt.pem
  csr: csr.pem
  pfx: crt.p12
}

# Create paths
def pts [stem: list<string> -c] {
  let dir = [$env.home $base ...$stem] | path join
  
  if $c {
    try {
      mkdir $dir
    } catch {|e| 
      print $'error: ($e.exit_code?)'
      exit $e.exit_code? | default 1
    }
  }

  {
    cnf: ($dir | path join 'cnf')
    key: ($dir | path join $conf.key)
    crt: ($dir | path join $conf.crt)
    csr: ($dir | path join $conf.csr)
    pfx: ($dir | path join $conf.pfx)
  }
}

# Create CA certificate
export def ca [--name(-n): string] {
  if $name == null {
    error make {msg: "required flag --name"}
  }
  
  let ca = pts [$conf.ca] -c

  let tpl = $"
    [ req ]
    default_md         = sha256
    default_days       = 3650
    default_bits       = 4096
    string_mask        = utf8only
    prompt             = no
    email_in_dn        = no
    copy_extensions    = copy
    unique_subject     = yes
    preserve           = no
    distinguished_name = dn
    x509_extensions    = v3_ca

    [ dn ]
    CN = ($name)
    O = ($name)
    

    [ v3_ca ]
    basicConstraints = critical, CA:TRUE, pathlen:0
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    keyUsage = critical, digitalSignature, cRLSign, keyCertSign
    nsCertType = sslCA, emailCA
  "
  $tpl | save -f $ca.cnf

  # Create CA
  openssl genpkey -algorithm RSA -out $ca.key -pkeyopt rsa_keygen_bits:4096
  openssl req -x509 -new -days $conf.cad -key $ca.key -out $ca.crt -config $ca.cnf -extensions v3_ca

  # Clean up
  rm $ca.cnf
}

# Create SMIME certificate
export def sm [--email(-e): string  --pass(-p): string] {
  if $email == null {
    error make {msg: "required flag --email"}
  }
  if $pass == null {
    error make {msg: "required flag --pass"}
  }
  if ($pass == "") {
    error make {msg: "password is empty"}
  }

  let ca = pts [$conf.ca]
  if not ([$ca.key $ca.crt] | path exists | all {}) {
    error make {msg: "ca not found"}
  }
  
  let sm = pts [$conf.sm $email (date now | format date "%y%m%d%H%M%S")] -c

  let tpl = $"
    [ req ]
    default_md = sha256
    default_days       = 3650
    default_bits       = 4096
    string_mask        = utf8only
    copy_extensions    = copy
    unique_subject     = yes
    prompt = no
    distinguished_name = dn
    req_extensions = v3_req

    [ dn ]
    CN = ($email)
    emailAddress = ($email)

    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = digitalSignature, keyEncipherment, nonRepudiation
    subjectKeyIdentifier = hash
    subjectAltName = email:copy
    extendedKeyUsage = emailProtection
    nsCertType = email
  "
  $tpl | save -f $sm.cnf
  
  # Create CSR
  openssl genpkey -algorithm RSA -out $sm.key -pkeyopt rsa_keygen_bits:4096
  openssl req -new -key $sm.key -out $sm.csr -config $sm.cnf

  # Sign CSR
  openssl x509 -req -days $conf.smd -in $sm.csr -CA $ca.crt -CAkey $ca.key -CAcreateserial -out $sm.crt -extfile $sm.cnf -extensions v3_req

  # Export to PKCS12
  openssl pkcs12 -export -inkey $sm.key -in $sm.crt -certfile $ca.crt -out $sm.pfx -passout pass:($pass)

  # Verify
  openssl x509 -in $sm.crt -purpose -noout -text

  # Clean up
  rm $sm.cnf
}
