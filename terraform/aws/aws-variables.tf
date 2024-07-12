####################################################################################################
# INSTRUCTIONS:
# (1) Customize these variables to your perference
# (2) Make sure the account you're running terraform with has proper permissions in your AWS env
####################################################################################################

# aws config
variable "aws_region" {
  default = "us-east-2"
}

# sdkperf nodes count
variable "sdkperf_nodes_count" {
  default     = "4"
  type        = string
  description = "The number of sdkperf nodes to be created."
}
variable "sdkperf_vm_type" {
  default = "t2.micro" # (2 CPUs  8G RAM - General Purpose)
}

# General Variables
variable "tag_owner" {
  default = "Hank Spencer"
}
variable "tag_days" {
  default = "3"
}
variable "tag_name_prefix" {
  default = "hspencer-sa"
}
variable "subnet_id" {
  default = ""
  #default = "subnet-0db7d4f1da1d01bd8"
  type        = string
  description = "The AWS subnet_id to be used for creating the nodes - Leave the value empty for automatically creating one."
}
variable "sdkperf_secgroup_ids" {
  default = [""]
  #default = ["sg-08a5f21a2e6ebf19e"]
  description = "The AWS security_group_ids to be asigned to the sdkperf nodes - Leave the value empty for automatically creating one."
}
# ssh config
# If the Key Pair is already created on AWS leave an empty public_key_path, otherwise terraform will try to create it and upload the public key
variable "aws_ssh_key_name" {
  default     = "hspencer_sdkperf_tfsa_key"
  description = "The Key pair Name to be created on AWS."
}
# If no  Private and Public Keys exist, they can be created with the "ssh-keygen -f ../aws_key" command
variable "public_key_path" {
  default     = "../../keys/aws_key.pub"
  description = "Local path to the public key to be uploaded to AWS"
}
variable "private_key_path" {
  default     = "../../keys/aws_key"
  description = "Local path to the private key used to connect to the Instances (Not to be uploaded to AWS)"
}
variable "ssh_user" {
  default     = "ec2-user"
  description = "SSH user to connect to the created instances (defined by the AMI being used)"
}

variable "centOS_ami" {
  type = map(any)
  default = { # CentOS with .NET 6.0 for us-east-2
    us-east-1 = "ami-0d8c288225dc75373"
    us-east-2 = "ami-0d8c288225dc75373"
    us-west-1 = "ami-0d8c288225dc75373"
    us-west-2 = "ami-0d8c288225dc75373"
  }
}

