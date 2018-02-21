variable "region" {
  description = "The AWS region to use when deploying the EC2 instance"
}

variable "profile" {
  description = "AWS profile to use. This can be created with 'aws configure' using the AWS Command Line"
}

variable "specs" {
  type        = "map"
  description = "EC2 Instance settings"
}

variable "password" {
  description = "User defined password for SciPy"
}
