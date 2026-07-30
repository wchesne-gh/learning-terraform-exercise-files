user_data = <<-EOF
#!/bin/bash
set -euo pipefail

dnf update -y
dnf install -y java-17-amazon-corretto curl tar

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
