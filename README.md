# ZentrumHub DevOps Assessment

This project implements the Alpha test environment and a Blue-Green deployment for the ZentrumHub DevOps assessment.

The infrastructure is created using Terraform and includes:

- AWS VPC
- Two public subnets across two Availability Zones
- Internet Gateway
- Application Load Balancer (ALB)
- Two ALB target groups for Blue and Green environments
- Auto Scaling Groups with two EC2 instances per environment
- Security groups restricting application traffic to the ALB
- S3 remote Terraform state
- DynamoDB state locking
- Weighted ALB traffic routing
- Bash scripts for deployment validation and traffic testing

The application is a minimal Nginx web server that displays its deployment version and EC2 instance ID.


## Architecture

Traffic flow -
Users access the application through the ALB.
The ALB listener forwards traffic to the Blue or Green target group based on Terraform-managed weights.

Example:

100/0  -> 100% Blue, 0% Green
90/10  -> 90% Blue, 10% Green
50/50  -> 50% Blue, 50% Green
0/100  -> 0% Blue, 100% Green

Blue remains running while Green is introduced so that traffic can be rolled back to Blue if required.

Project Structure -

Zentrumhub_DevOps_Assessment/
│
├── .gitignore
├── README.md
│
├── bootstrap/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── infrastructure/
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   ├── versions.tf
│   │
│   └── modules/
│       └── application/
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── user_data.sh
│
└── scripts/
    ├── test-cutover.sh
    └── test-canary.sh

4. Remote Terraform State

Before deploying the main infrastructure, I created the resources required for Terraform remote state:

S3 Bucket
DynamoDB Table
   
The S3 bucket I used was:

zentrumhub-devops-bucket-1

and the DynamoDB lock table was:

zentrumhub-devops-tflock

The assessment explicitly required an S3 backend with a DynamoDB lock table.

The purpose is:
S3 stores Terraform state centrally.
DynamoDB prevents multiple Terraform operations from modifying state at the same time.

5. AWS Provider and Variables

The AWS region was:

ap-south-1

I made environment-specific values variables rather than hardcoding them.

For example:

aws_region    = "ap-south-1"
ami_id        = "ami-0c0fd09cfe77b59dc"
instance_type = "t3.micro"

blue_version  = "alpha-v1.0"
green_version = "beta-v2.0"

specifically variables for the AMI, instance type and version tag.

The traffic weights are also variables like:

blue_weight  = 100
green_weight = 0

This allowed me to change traffic using Terraform rather than manually modifying the ALB in the AWS Console.

6. VPC Creation

Terraform creates a VPC:

CIDR: 10.0.0.0/16

Inside the VPC, I created two public subnets across two Availability Zones.

VPC
10.0.0.0/16
 - Public Subnet - AZ1
 - Public Subnet - AZ2

also created:

Internet Gateway
Route Table
Route Table Associations

The public subnets have a route to the Internet Gateway.

7. Security Groups

created separate security groups for the ALB and application instances.

-- ALB Security Group

The ALB accepts HTTP traffic from the internet:

The ALB security group allows HTTP traffic.

-- EC2 Security Group

The EC2 security group does not allow HTTP from:

0.0.0.0/0

Instead, it allows HTTP only from the ALB security group:
Therefore users cannot directly access the application instances.

8. Application Load Balancer

Terraform creates an Application Load Balancer.

ALB:
is internet-facing
is deployed across the two public subnets
listens on HTTP port 80
forwards requests to target groups

Initially, Alpha/Blue was the active environment.
The ALB also provides the DNS endpoint that we used for testing.

9. Blue Target Group

created the first target group for the Alpha application:

alpha-blue-tg

It listens on:
HTTP :80

and performs health checks against:

/

Only healthy instances receive traffic.

10. Reusable Application Module

Instead of writing the EC2 infrastructure twice, I created:

modules/application/

This module contains the common application infrastructure:

Security Group
Launch Template
Auto Scaling Group
User Data

The same module is then called twice:

module "blue"
module "green"

11. Launch Template

The application module creates an EC2 Launch Template.

The Launch Template receives:
AMI ID
Instance type
Security Group
application version

For test environment used:

AMI: Ubuntu 24.04
Instance type: t3.micro

12. User Data — Installing Nginx

When an EC2 instance starts, the user_data.sh script runs automatically.

The script:

Updates packages
Installs Nginx
Gets the EC2 instance ID from the EC2 metadata service
Creates an HTML page
Displays the application version
Displays the instance ID
Starts Nginx

The resulting page looks like:

alpha-v1.0
Instance ID: i-xxxxxxxxxxxxxxxxx

13. Auto Scaling Group

The module creates an Auto Scaling Group with:

minimum       = 2
desired       = 2
maximum       = 2

Therefore Alpha initially runs two EC2 instances:

Blue ASG
 - EC2 - AZ1
 - EC2 - AZ2

The instances are automatically registered with the Blue target group.
The ALB health checks determine whether they are healthy.

14. Terraform Validation

Before applying the infrastructure, ran:

terraform fmt
terraform validate
terraform plan

Then:

terraform apply


15. Alpha / Blue Environment

After Terraform applied successfully, the Alpha environment was running.

The traffic flow was:

Internet
   |
  ALB
   |
Blue Target Group
   |
   +---- EC2
   |
   +---- EC2

Traffic configuration:

Blue  = 100%
Green = 0%

I tested the ALB endpoint and confirmed that the application returned:

alpha-v1.0
along with the EC2 instance ID.

16. Creating Green Environment

The next requirement was to deploy Beta without disturbing Alpha.
Instead of creating another copy of the Terraform code, I reused the same application module:

module "blue"
module "green"

The Green environment uses:

version = beta-v2.0

and has its own:

Security Group
Launch Template
Auto Scaling Group
EC2 instances
Target Group

Both environments can therefore run simultaneously.

17. ALB Weighted Routing

Instead of manually changing the target group in the AWS Console, Terraform controls the weights:

blue_weight  = 100
green_weight = 0

For example:

100% Blue
Blue  = 100
Green = 0

90/10 Canary
Blue  = 90
Green = 10

50/50
Blue  = 50
Green = 50

100% Green
Blue  = 0
Green = 100

This follows to use ALB listener/target-group weighting only, without an external traffic-shaping tool.

18. Testing 100% Blue

Before moving traffic, I confirmed that Blue was serving all traffic:

Blue  = 100%
Green = 0%

I used the testing script to send multiple requests to the ALB.

The result was:

Blue responses: 50
Green responses: 0
Failed requests: 0

This confirmed that the initial environment was healthy.
The assessment specifically requires confirmation of 100% Blue before starting the cutover.

19. Green Health Verification

Before sending production/test traffic to Green,confirmed that the Green instances were healthy in the Green target group.

So at this point:

BLUE
2 healthy instances
alpha-v1.0

GREEN
2 healthy instances
beta-v2.0

But traffic was still:

100% Blue
0% Green

Therefore creating Green had no impact on the current Blue traffic.

20. Canary Deployment — 90/10

Implemented gradual traffic shifting.

First:

Blue  = 90%
Green = 10%

Then I ran the test loop against the ALB.

The loop checked each response:

alpha-v1.0 → BLUE
beta-v2.0  → GREEN

This allowed me to verify that traffic was reaching both environments.

21. Canary Deployment — 50/50

Next, I changed the Terraform variables:

Blue  = 50%
Green = 50%

and applied Terraform.

Then I ran the same testing loop again.

The output showed responses from both:

BLUE
GREEN
BLUE
GREEN

with no failed requests during the validation.

22. Full Cutover — 0/100

After validating the Green environment, I performed the full cutover:

Blue  = 0%
Green = 100%

changed the Terraform variables and ran:

terraform apply

After the change, the ALB sent traffic entirely to Green.
The application response changed from:

alpha-v1.0

to:

beta-v2.0

I then ran the request loop again and confirmed successful responses with no failed requests.


23. Rollback

After the Green deployment, I changed the weights back:

Blue  = 100%
Green = 0%

and ran:

terraform apply

Traffic immediately returned to Blue.

The response changed back to:

alpha-v1.0

ran the same test loop and confirmed successful Blue responses.

Therefore the deployment was reversible using the same Terraform-controlled ALB weighting mechanism

24. Testing Scripts

created two simple scripts.

test-cutover.sh
This script:

Sends multiple requests to the ALB.
Checks whether the expected version is returned.
Counts successful requests.
Counts failed requests.
Prints PASS/FAIL.

test-canary.sh
This script:

Sends multiple requests to the ALB.
Checks whether the response is Blue or Green.
Counts Blue responses.
Counts Green responses.
Counts failed responses.

This gave us evidence that weighted routing was actually sending requests to both versions.

25. Final Cleanup

lastly, destroyed the environment:

terraform destroy
