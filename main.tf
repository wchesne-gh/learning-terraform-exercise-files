resource "aws_spot_instance_request" "tomcat_spot" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [aws_security_group.tomcat_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  spot_type              = "one-time"

  user_data = <<-EOF
#!/bin/bash
set -euo pipefail

dnf update -y
dnf install -y java-17-amazon-corretto

id tomcat &>/dev/null || useradd -r -m -U -d /opt/tomcat -s /sbin/nologin tomcat

TOMCAT_VERSION=${var.tomcat_version}
TOMCAT_MAJOR=${var.tomcat_major}
TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-$${TOMCAT_MAJOR}/v$${TOMCAT_VERSION}/bin/apache-tomcat-$${TOMCAT_VERSION}.tar.gz"

cd /tmp
curl -fL --retry 5 --retry-delay 2 -o apache-tomcat-$${TOMCAT_VERSION}.tar.gz "$TOMCAT_URL"

rm -rf /opt/tomcat
mkdir -p /opt/tomcat
tar xzf /tmp/apache-tomcat-$${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1
chown -R tomcat:tomcat /opt/tomcat
EOF

  tags = {
    Name = "tomcat-spot"
  }
}
