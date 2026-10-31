terraform {
  backend "s3" {
    bucket       = "cob-tfstate-428232898428"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
