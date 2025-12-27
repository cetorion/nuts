export def main [] {

  let email = 'nero@asgard.id' # (input "Enter email: ")
  let pass = 'testtest' # (input "Enter PFX password: ")
  let days = 3650

  let out_dir = './smime'
  let dome = ($email | split row '@' | last | split row '.' | first | str capitalize)
  let name = ($email | split row '@' | first | str capitalize)

  if ($out_dir | path exists) {
    rm -rf $out_dir
  }
  mkdir $out_dir

  let smime_cnf = $"($out_dir)/smime.cnf"

  let ca_key = $"($out_dir)/ca.key"
  let ca_crt = $"($out_dir)/ca.crt"

  let smime_key = $"($out_dir)/smime.key"
  let smime_csr = $"($out_dir)/smime.csr"
  let smime_crt = $"($out_dir)/smime.crt"
  let smime_pfx = $"($out_dir)/smime.p12"

  let cnf = $"
  [req]
  prompt = no
  default_md = sha256
  distinguished_name = dn
  req_extensions = v3_req
  x509_extensions = v3_ca

  [dn]
  CN = ($dome)
  emailAddress = ($email)

  [ v3_req ]
  basicConstraints = CA:FALSE
  keyUsage = nonRepudiation, digitalSignature, keyEncipherment
  subjectKeyIdentifier = hash
  subjectAltName = email:copy
  extendedKeyUsage = emailProtection

  [ v3_ca ]
  subjectKeyIdentifier = hash
  authorityKeyIdentifier = keyid:always,issuer
  basicConstraints = critical, CA:TRUE, pathlen:0
  keyUsage = critical, cRLSign, keyCertSign, digitalSignature
  "

  $cnf | save $smime_cnf

  # Create CA
  openssl genpkey -algorithm RSA -out $ca_key -pkeyopt rsa_keygen_bits:4096
  openssl req -x509 -new -key $ca_key -days $days -out $ca_crt -config $smime_cnf -extensions v3_ca

  # Create CSR
  openssl genpkey -algorithm RSA -out $smime_key -pkeyopt rsa_keygen_bits:4096
  openssl req -new -key $smime_key -out $smime_csr -config $smime_cnf

  # Sign
  openssl x509 -req -days $days -in $smime_csr -CA $ca_crt -CAkey $ca_key -CAcreateserial -out $smime_crt -extfile $smime_cnf -extensions v3_req

  # Export to PKCS12
  if ($pass == '') {
    openssl pkcs12 -export -inkey $smime_key -in $smime_crt -certfile $ca_crt -out $smime_pfx -nodes
  } else {
    openssl pkcs12 -export -inkey $smime_key -in $smime_crt -certfile $ca_crt -out $smime_pfx -passout $"pass:($pass)"
  }

  # Verify
  openssl x509 -in $smime_crt -purpose -noout -text
}
