
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_ami" "amzn2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "tomcat_sg" {
  name        = "tomcat-spot-sg"
  description = "Allow SSH and Tomcat"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_PUBLIC_IP/32"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["YOUR_PUBLIC_IP/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "tomcat_spot" {
  ami                    = data.aws_ami.amzn2023.id
  instance_type          = "t3.small"
  subnet_id              = "subnet-xxxxxxxx"
  vpc_security_group_ids = [aws_security_group.tomcat_sg.id]
  key_name               = "your-keypair"

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
      instance_interruption_behavior = "terminate"
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail

              dnf update -y
              dnf install -y java-17-amazon-corretto wget tar

              useradd -r -m -U -d /opt/tomcat -s /sbin/nologin tomcat || true

              TOMCAT_VERSION=10.1.24
              cd /tmp
              wget https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.56/bin/apache-tomcat-10.1.56.tar.gz
              mkdir -p /opt/tomcat
              tar xzf apache-tomcat-10.1.56.tar.gz-C /opt/tomcat --strip-components=1
              chown -R tomcat:tomcat /opt/tomcat

              cat >/etc/systemd/system/tomcat.service <<'UNIT'
              [Unit]
              Description=Apache Tomcat
              After=network.target

              [Service]
              Type=forking
              User=tomcat
              Group=tomcat
              Environment=JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
              Environment=CATALINA_HOME=/opt/tomcat
              Environment=CATALINA_BASE=/opt/tomcat
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
