# Production-Grade Improvements

The assessment environment is intentionally small and cost-optimized. For a production environment, I would make the following improvements.

### Networking
I would place the EC2 application instances in private subnets and keep the ALB in public subnets. NAT Gateway or VPC endpoints would be added only where required.

### HTTPS
I would configure HTTPS on the ALB using AWS Certificate Manager and redirect HTTP traffic to HTTPS.

### Security
follow least-privilege IAM policies and avoid direct SSH access where possible. AWS Systems Manager would be preferred for instance management. Secrets would be stored in AWS Secrets Manager or Parameter Store.

### Compute
would use production-appropriate instance types, Auto Scaling policies and health checks based on actual workload requirements. A pre-built AMI or image pipeline would reduce dependency on package installation during instance startup.

### Monitoring
would add CloudWatch alarms and dashboards for ALB 5xx errors, target health, response latency and EC2 resource utilization. Centralized application logs would also be enabled.

### Terraform State
The remote state would be protected with encryption, versioning and restricted IAM access. State locking would remain enabled.

### Deployment
The weighted ALB approach used in this assessment can be extended with automated canary promotion based on error rate, latency and application health. Blue would remain available during the rollout to provide a fast rollback path.

### Reliability and Cost
Production capacity, Multi-AZ requirements, backups and disaster recovery would be based on the application's availability and workload requirements rather than the small assessment environment.