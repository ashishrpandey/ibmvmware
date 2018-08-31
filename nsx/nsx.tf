# nsx related setup 

provider "nsxt" {
  host                     = "192.168.110.41"
  username                 = "admin"
  password                 = "zekeLabs123"
  allow_unverified_ssl     = true
  max_retries              = 10
  retry_min_delay          = 500
  retry_max_delay          = 5000
  retry_on_status_codes    = [429]
}

# An alternate way to provide few fields of configuration
#Example of Setting Environment Variables

export NSXT_MANAGER_HOST="192.168.110.41"
export NSXT_USERNAME="admin"
export NSXT_PASSWORD="zekeLabs123"

#Using a Client Certificate
provider "nsxt" {
  host                  = "192.168.110.41"
  client_auth_cert_file = "zekeLabscert.pem"  	#NSXT_CLIENT_AUTH_CERT_FILE
  client_auth_key_file  = "zekeLabskey.pem"		#NSXT_CLIENT_AUTH_KEY_FILE
  allow_unverified_ssl  = true					#NSXT_ALLOW_UNVERIFIED_SSL
}

# Using a Certificate Authority Certificate
provider "nsxt" {
  host     = "10.160.94.11"
  username = "admin"
  password = "zekeLabs123"
  ca_file  = "zekeLabsCA.pem"
}
