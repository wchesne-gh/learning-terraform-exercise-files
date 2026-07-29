variable "instance_type" {
  description = "Type of EC2 instance to provision"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your public IP address in CIDR notation for SSH and Tomcat access"
  type        = string
}
