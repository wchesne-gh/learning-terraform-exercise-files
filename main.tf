# 1. Security Group to allow SSH and Tomcat web traffic
resource "aws_security_group" "tomcat_sg" {
  name        = "tomcat-security-group"
  description = "Allow SSH and Tomcat web traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For production, restrict this to your IP
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. EC2 Spot Instance using pre-configured Tomcat 11 AMI
resource "aws_instance" "web" {
  ami                    = "ami-02cab4f0ea4dc8a19"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.tomcat_sg.id]

  # Spot Instance Configuration
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price          = "0.01" # Adjust maximum hourly price if needed
      spot_instance_type = "one-time"
    }
  }

  tags = {
    Name = "Tomcat11-Spot-Server"
  }
}

# 3. Output the public URL to access Tomcat
output "tomcat_url" {
  value       = "http://${aws_instance.web.public_ip}:8080"
  description = "The public URL of the Tomcat server"
}
