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

variable "tomcat_version" {
  description = "Apache Tomcat version to install"
  type        = string
  default     = "10.1.24"
}

variable "tomcat_major" {
  description = "Apache Tomcat major release series"
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
    cidr_blocks = [var.my_ip_cidr]
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
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.tomcat_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  spot_type              = "one-time"

  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail

              dnf update -y
              dnf install -y java-17-amazon-corretto curl tar

              id tomcat &>/dev/null || useradd -r -m -U -d /opt/tomcat -s /sbin/nologin tomcat

              TOMCAT_VERSION=${var.tomcat_version}
              TOMCAT_MAJOR=${var.tomcat_major}
              TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

              cd /tmp
              curl -fL --retry 5 --retry-delay 2 -o apache-tomcat-${TOMCAT_VERSION}.tar.gz "$TOMCAT_URL"

              rm -rf /opt/tomcat
              mkdir -p /opt/tomcat
              tar xzf /tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1
              chown -R tomcat:tomcat /opt/tomcat

              cat >/etc/systemd/system/tomcat.service <<'UNIT'
              [Unit]
              Description=Apache Tomcat
              After=network.target

              [Service]
              Type=forking
              User=tomcat
              Group=tomcat
              Environment="JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto"
              Environment="CATALINA_HOME=/opt/tomcat"
              Environment="CATALINA_BASE=/opt/tomcat"
              ExecStart=/opt/tomcat/bin/startup.sh
              ExecStop=/opt/tomcat/bin/shutdown.sh
              Restart=on-failure

              [Install]
              WantedBy=multi-user.target
              UNIT

              chmod +x /opt/tomcat/bin/*.sh
              systemctl daemon-reload
              systemctl enable tomcat
              systemctl start tomcat
              EOF

  tags = {
    Name = "tomcat-spot"
  }
}
