#!/bin/bash

apt-get update -y
apt-get install -y nginx

TOKEN=$(curl -s -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)

INSTANCE_ID=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

cat > /var/www/html/index.html <<EOF
<html>
<head>
    <title>DevOps Assessment</title>
</head>
<body>
    <h1>${app_version}</h1>
    <p>Instance ID: $${INSTANCE_ID}</p>
</body>
</html>
EOF

systemctl enable nginx
systemctl start nginx