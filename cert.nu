def main [
  --base (-b): string = "./certs"
  --pass (-p): string
  --email (-e): string
  --ca(-c)
  --smime(-s)
  --delete(-d)
] {
  let default = {
    email: 'nero@asgard.id'
    pass: 'testify'
  }

  if $delete {
    let ask = (input $"Delete existing '($base)' ? \(y/n\): ")
    if ($ask == 'y') {
      rm -rf $base
    } else {
      print "Skipping ..."
    }
  }

  mut email = $email
  if ($email == null) or ($email == "") {
    $email = (input "Enter email: ")
    if ($email == "") {
      $email = $default.email
    }
  }

  mut pass = $pass
  if ($pass == null) or ($pass == "") {
    $pass = (input "Enter PFX password: ")
    if ($pass == "") {
      $pass = $default.pass
    }
  }

  let dome = ($email | split row '@' | last | split row '.' | first | str capitalize)
  let name = ($email | split row '@' | first | str capitalize)
  let days = 3650

  if not ($base | path exists) {
    mkdir $base
  }
  
  if $ca {
    ca $base $dome
  }
  
  if $smime {
    smime $base $email $pass
  }

}

def ca [base: string dome: string] {
  let ca = $"($base)/ca"
  mkdir $ca
   
  let ca_cnf = $"($ca)/ca.cnf"
  let ca_key = $"($ca)/ca.key"
  let ca_crt = $"($ca)/ca.crt"

  let cnf = $"
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
    O  = Personal
    CN = ($dome)
    OU = ($dome)
    

    [ v3_ca ]
    basicConstraints = critical, CA:TRUE, pathlen:0
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    keyUsage = critical, digitalSignature, cRLSign, keyCertSign
    nsCertType = sslCA, emailCA
  "
  $cnf | save -f $ca_cnf

  openssl genpkey -algorithm RSA -out $ca_key -pkeyopt rsa_keygen_bits:4096
  openssl req -x509 -new -key $ca_key -out $ca_crt -config $ca_cnf -extensions v3_ca
}


def smime [base: string email: string  pass?: string] {
  let ca = $"($base)/ca"
  let ca_key = $"($ca)/ca.key"
  let ca_crt = $"($ca)/ca.crt"
  if not ([$ca_key $ca_crt] | path exists | all {}) {
    print 'error: ca keys not fount'
    exit 1
  }
  
  let smime = $"($base)/smime"
  mkdir $smime
  let smime_cnf = $"($smime)/smime.cnf"
  let smime_key = $"($smime)/smime.key"
  let smime_csr = $"($smime)/smime.csr"
  let smime_crt = $"($smime)/smime.crt"
  let smime_pfx = $"($smime)/smime.p12"
   

  let cnf = $"
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
    O  = Personal
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
  $cnf | save -f $smime_cnf
  
  mut opt = []
  if ($pass != null) and ($pass != "") {
    $opt = [-passout pass:($pass)]
  } else {
    $opt = [-nodes]
  }

  # Create CSR
  openssl genpkey -algorithm RSA -out $smime_key -pkeyopt rsa_keygen_bits:4096
  openssl req -new -key $smime_key -out $smime_csr -config $smime_cnf

  # Sign
  openssl x509 -req -in $smime_csr -CA $ca_crt -CAkey $ca_key -CAcreateserial -out $smime_crt -extfile $smime_cnf -extensions v3_req

  # Export to PKCS12
  openssl pkcs12 -export -inkey $smime_key -in $smime_crt -certfile $ca_crt -out $smime_pfx ...$opt

  # Verify
  openssl x509 -in $smime_crt -purpose -noout -text
  
}
