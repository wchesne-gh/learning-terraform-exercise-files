#variable "instance_type" {
#  description = "Type of EC2 instance to provision"
#  default     = "t3.micro"
#}
variable "my_ip_cidr" {
  description = "Your public IP address in CIDR notation for SSH and Tomcat access"
  type        = string
}
