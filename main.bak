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
  description = "Your public IP address in CIDR notation for Tomcat access"
  type        = string
}

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

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
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

resource "aws_security_group" "tomcat_sg" {
  name        = "tomcat-spot-sg"
  description = "Allow Tomcat access"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tomcat-spot-sg"
  }
}

resource "aws_spot_instance_request" "tomcat_spot" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  spot_type            = "one-time"

  vpc_security_group_ids = [aws_security_group.tomcat_sg.id]

  user_data = <<-EOF
#!/bin/bash
# Send script output to log files for easy debugging if it fails
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/null) 2>&1

set -e # Exit immediately if any command fails

# 1. Update OS and detect system version to install Java
if grep -q "release 2023" /etc/system-release; then
    echo "Detected Amazon Linux 2023"
    dnf update -y
    dnf install java-17-amazon-corretto-devel wget -y
else
    echo "Detected Amazon Linux 2"
    yum update -y
    amazon-linux-extras install java-openjdk11 -y
    yum install wget -y
fi

# 2. Create a restricted system user for Tomcat
groupadd tomcat
useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

# 3. Download and extract Tomcat 10 from the official archive mirror
cd /tmp
wget https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.56/bin/apache-tomcat-10.1.56.tar.gz
mkdir -p /opt/tomcat
tar -xzf apache-tomcat-10.1.56.tar.gz -C /opt/tomcat --strip-components=1

# 4. Set secure folder permissions
chown -R tomcat:tomcat /opt/tomcat
chmod -R 755 /opt/tomcat

# 5. Dynamically calculate the accurate system path for JAVA_HOME
DETECTED_JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))

# 6. Create the Systemd service configuration
cat << SYSTEMD > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Server
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment="JAVA_HOME=$DETECTED_JAVA_HOME"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
SYSTEMD

# 7. Reload systemd daemons, enable boot persistent execution, and start Tomcat
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat

echo "Tomcat setup execution finished successfully!"

EOF

  tags = {
    Name = "tomcat-spot"
  }
}
