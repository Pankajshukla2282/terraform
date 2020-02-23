# terraform
Terraform modules


# For SSH access, do below-
Use PuttyGen to -
    1. create new SSH key pair
    2. export private key to .pem
    3. save .ppk and .pub files also 

# apply
terraform apply -var 'key_name=terraform' -var 'public_key_path=~/.ssh/terraform.pub' -var 'private_key_path=~/.ssh/terraform.pem'
# destroy
terraform destroy

