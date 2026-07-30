
#variable "instance_type" {
#  description = "Type of EC2 instance to provision"
#  type        = string
#  default     = "t3.micro"
#}

#variable "subnet_id" {
#  description = "Subnet ID for the EC2 instance"
 # type        = string
#}

#variable "my_ip_cidr" {
 # description = "Your public IP address in CIDR notation for Tomcat access"
  #type        = string
#}

variable "tomcat_version" {
  description = "Apache Tomcat version to install"
  type        = string
  default     = "10.1.24"
}

variable "tomcat_major" {
  description = "Apache Tomcat major release"
  type        = string
  default     = "10"
}

#data "aws_ami" "al2023" {
 # most_recent = true
  #owners      = ["amazon"]

  #filter {
    #name   = "name"
 #  #values = ["al2023-ami-*-x86_64"]
#  }
}

 #data "aws_iam_policy_document" "ec2_assume_role" {
   #statement {
     #effect = "Allow"

     #principals {
       #type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_ssm_role" {
  name               = "tomcat-spot-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "tomcat-spot-ec2-profile"
  role = aws_iam_role.ec2_ssm_role.name
}



 #resource "aws_spot_instance_request" "tomcat_spot" {
   #ami                  = data.aws_ami.al2023.id
   #instance_type        = var.instance_type
 #  subnet_id            = var.subnet_id
   #iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
   #spot_type            = "one-time"

   #vpc_security_group_ids = [aws_security_group.tomcat_sg.id]



  tags = {
    Name = "tomcat-spot"
  }
}
