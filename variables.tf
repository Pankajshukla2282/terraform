variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/terraform.pub
DESCRIPTION
  default     = "~/.ssh/terraform.pub"
}

variable "private_key_path" {
  description = <<DESCRIPTION
Path to the SSH private key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/terraform.pem
DESCRIPTION
  default     = "~/.ssh/terraform.pem"
}

variable "key_name" {
  description = "Desired name of AWS key pair"
  default     = "terraform"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "ap-south-1"
}

variable "aws_az1" {
  description = "AWS Availability Zone to launch servers."
  default     = "ap-south-1a"
}
variable "aws_az2" {
  description = "AWS Availability Zone to launch servers."
  default     = "ap-south-1b"
}

variable "aws_amis" {
  default = {
    ap-south-1 = "ami-0d9462a653c34dab7"
  }
}