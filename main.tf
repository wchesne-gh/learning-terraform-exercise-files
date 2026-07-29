# 1. Fetch the latest clean Amazon Linux 2 AMI
data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Create a Security Group to allow web traffic to Tomcat
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

# 3. Provision the EC2 Spot Instance with a Tomcat setup script
resource "aws_instance" "web" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = "t3.nano"
  vpc_security_group_ids = [aws_security_group.tomcat_sg.id]

  # Configure this as a Spot Instance
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price          = "0.01" # Adjust maximum hourly price if needed
      spot_instance_type = "one-time"
    }
  }

  # Script to install Java and Tomcat 10 automatically
  user_data = <<-EOF
              #!/bin/bash
set -e

# Install dependencies
yum update -y
yum install -y wget

# Install Java 11
amazon-linux-extras install java-openjdk11 -y

# Create Tomcat user
useradd -m -U -d /opt/tomcat -s /bin/false tomcat

# Download Tomcat (CORRECT URL)
cd /tmp
wget https://downloads.apache.org/tomcat/tomcat-10/v10.1.18/bin/apache-tomcat-10.1.18.tar.gz

# Extract
mkdir -p /opt/tomcat
tar -xzf apache-tomcat-10.1.18.tar.gz -C /opt/tomcat --strip-components=1

# Permissions
chown -R tomcat:tomcat /opt/tomcat
chmod -R 755 /opt/tomcat

# Systemd service
cat << 'SYSTEMD' > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto.x86_64"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

Restart=on-failure

[Install]
WantedBy=multi-user.target
SYSTEMD

# Start service
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat
EOF

  tags = {
    Name = "Tomcat-Spot-Server"
  }
}

# 4. Output the public IP to access Tomcat after deployment
output "tomcat_url" {
  value       = "http://${aws_instance.web.public_ip}:8080"
  description = "The public URL of the Tomcat server"
}
