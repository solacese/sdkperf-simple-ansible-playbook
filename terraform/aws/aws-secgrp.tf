####################################################################################################
# NOTE: The following network resources will only get created if:
# The "sdkperf_secgroup_ids" variable is left "empty"
####################################################################################################

#Query the VPC id for the specified VPC subnet
data "aws_subnet" "input_subnet_id" {
  count = var.subnet_id == "" ? 0 : 1

  id = var.subnet_id
}

resource "aws_security_group" "sdkperf_secgroup" {
  #If no sdkperf security group was specified, we'll create one
  count = var.sdkperf_secgroup_ids == [""] ? 1 : 0

  #If a VPC Subnet was specified we'll query its VPC id and use it, otherwise use the VPC that was just created
  vpc_id = var.subnet_id == "" ? aws_vpc.sdkperf_vpc[0].id : data.aws_subnet.input_subnet_id[0].vpc_id

  name        = "sdkperf_secgroup"
  description = "Allow SSH traffic to sdkperf benchmarking instances"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.tag_name_prefix}-sdkperf-secgroup"
    Owner   = var.tag_owner
    Purpose = "sdkperf benchmarking"
    Days    = var.tag_days
  }
}
