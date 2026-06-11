###############################################################
# Backend — S3 + DynamoDB state locking
# Update bucket name and table before applying
###############################################################

terraform {
  backend "s3" {
    bucket         = "mct-au-terraform-state"        # update with your bucket name
    key            = "stage/network-hub/terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
    dynamodb_table = "mct-au-terraform-locks"        # update with your DynamoDB table name
  }
}
