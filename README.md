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

**Remote Terraform State**

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
<img width="1359" height="721" alt="Screenshot 2026-09-14 010851" src="https://github.com/user-attachments/assets/e21e614d-f68a-4ae2-b401-f985cd96ee11" />

<img width="1365" height="723" alt="Screenshot 2026-09-14 013053" src="https://github.com/user-attachments/assets/4db7af91-d47e-442b-9612-44ccb3fef9cc" />

**AWS Provider and Variables**

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

**VPC Creation**

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

**Security Groups**

created separate security groups for the ALB and application instances.

-- ALB Security Group

The ALB accepts HTTP traffic from the internet:

The ALB security group allows HTTP traffic.

-- EC2 Security Group

The EC2 security group does not allow HTTP from:

0.0.0.0/0

Instead, it allows HTTP only from the ALB security group:
Therefore users cannot directly access the application instances.

**Application Load Balancer**

Terraform creates an Application Load Balancer.

ALB:
is internet-facing
is deployed across the two public subnets
listens on HTTP port 80
forwards requests to target groups

Initially, Alpha/Blue was the active environment.
The ALB also provides the DNS endpoint that we used for testing.

**Blue Target Group**

created the first target group for the Alpha application:

alpha-blue-tg

It listens on:
HTTP :80

and performs health checks against:
/
Only healthy instances receive traffic.
<img width="1353" height="718" alt="Screenshot 2026-09-14 022730" src="https://github.com/user-attachments/assets/be01c969-eb86-41bd-a221-7a8665828327" />

**Reusable Application Module**

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

**Launch Template**

The application module creates an EC2 Launch Template.

The Launch Template receives:
AMI ID
Instance type
Security Group
application version

For test environment used:

AMI: Ubuntu 24.04
Instance type: t3.micro

**User Data — Installing Nginx**

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

<img width="1363" height="614" alt="Screenshot 2026-09-14 033115" src="https://github.com/user-attachments/assets/aeced57d-47cc-41e7-81c4-07c33af7b4b5" />

<img width="1358" height="673" alt="Screenshot 2026-09-14 033739" src="https://github.com/user-attachments/assets/1abd1601-4415-47f3-b86c-2da4eecf8c15" />

**Auto Scaling Group**

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

<img width="1362" height="717" alt="Screenshot 2026-09-14 035530" src="https://github.com/user-attachments/assets/f4296050-d781-492e-b28b-ee436db0aad2" />

terraform Validation
Before applying the infrastructure, ran:

terraform fmt
terraform validate
terraform plan

Then:

terraform apply

**Alpha / Blue Environment**

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

<img width="1357" height="713" alt="Screenshot 2026-09-14 023805" src="https://github.com/user-attachments/assets/9a25fa01-de6f-4e62-9106-a59a9229c45e" />

<img width="1292" height="467" alt="Screenshot 2026-09-14 141750" src="https://github.com/user-attachments/assets/a2da7ce5-57ff-4ce8-a9f1-fdea8741c059" />

<img width="1113" height="630" alt="Screenshot 2026-09-14 141806" src="https://github.com/user-attachments/assets/67f7e961-71fe-4101-84d3-f7574cfbfd2b" />

<img width="1364" height="631" alt="Screenshot 2026-09-14 142030" src="https://github.com/user-attachments/assets/f9e27966-16e4-4dae-8fd5-96c07518c02d" />

<img width="1356" height="680" alt="Screenshot 2026-09-14 142053" src="https://github.com/user-attachments/assets/4e8f2281-29cc-4fcc-a663-951663407b55" />

**Creating Green Environment**

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

**ALB Weighted Routing**

Instead of manually changing the target group in the AWS Console, Terraform controls the weights:

For example:

100% Blue
Blue  = 100
Green = 0
<img width="1358" height="655" alt="Screenshot 2026-09-14 145825" src="https://github.com/user-attachments/assets/9bb277ce-7ce2-4389-873e-0411a60b9b94" />

90/10 Canary
Blue  = 90
Green = 10
<img width="1352" height="679" alt="Screenshot 2026-09-14 150451" src="https://github.com/user-attachments/assets/4ba8a484-feb0-4b22-a7b6-06f73fc2e4e9" />

<img width="1365" height="694" alt="Screenshot 2026-09-14 150404" src="https://github.com/user-attachments/assets/6b65c805-73a2-4e38-a026-734f564534bc" />

50/50
Blue  = 50
Green = 50
<img width="1349" height="705" alt="Screenshot 2026-09-14 150859" src="https://github.com/user-attachments/assets/647e72ae-076a-4a02-b718-62ad4f911de4" />

<img width="1365" height="694" alt="Screenshot 2026-09-14 151045" src="https://github.com/user-attachments/assets/fd0ec99b-39a3-45f3-bc3b-a54430f42fc2" />

100% Green
Blue  = 0
Green = 100
<img width="1365" height="712" alt="Screenshot 2026-09-14 151602" src="https://github.com/user-attachments/assets/86f502bc-4aca-4106-8e69-e1b30b5c68b9" />

<img width="1363" height="622" alt="Screenshot 2026-09-14 151818" src="https://github.com/user-attachments/assets/3de047d8-09fd-4077-9ced-5d649da75333" />

<img width="1365" height="710" alt="Screenshot 2026-09-14 151955" src="https://github.com/user-attachments/assets/9e05f761-b23c-46ad-ba64-6783b35165c7" />

<img width="1365" height="683" alt="Screenshot 2026-09-14 152501" src="https://github.com/user-attachments/assets/2843431b-5929-4730-8c1c-391f218a4b6f" />

<img width="1360" height="629" alt="Screenshot 2026-09-14 152517" src="https://github.com/user-attachments/assets/937a0748-8f65-4e47-81db-41f6258d71f0" />

This follows to use ALB listener/target-group weighting only, without an external traffic-shaping tool.

Testing 100% Blue

Before moving traffic, I confirmed that Blue was serving all traffic:

Blue  = 100%
Green = 0%

I used the testing script to send multiple requests to the ALB.

The result was:

Blue responses: 50
Green responses: 0
Failed requests: 0
This confirmed that the initial environment was healthy.

**Green Health Verification**

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

**Canary Deployment — 90/10**

Implemented gradual traffic shifting.

First:

Blue  = 90%
Green = 10%

Then I ran the test loop against the ALB.

The loop checked each response:

alpha-v1.0 → BLUE
beta-v2.0  → GREEN

This allowed me to verify that traffic was reaching both environments.

Canary Deployment — 50/50

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

**Full Cutover — 0/100**

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

**Rollback**

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

<img width="1365" height="716" alt="Screenshot 2026-09-14 152927" src="https://github.com/user-attachments/assets/1b78a2de-ebec-44fd-8c61-b1b069304737" />
<img width="1361" height="718" alt="Screenshot 2026-09-14 153001" src="https://github.com/user-attachments/assets/0aa84b31-2535-477f-8862-a54b60612c5b" />
<img width="1365" height="675" alt="Screenshot 2026-09-14 153120" src="https://github.com/user-attachments/assets/2e6f0d01-b86f-4388-b03c-efd3e2aa8c6e" />
<img width="1364" height="674" alt="Screenshot 2026-09-14 153133" src="https://github.com/user-attachments/assets/a9e99b22-f89a-477f-a43e-5c4a569f1a81" />

**Testing Scripts**

created two simple scripts.

**test-cutover.sh**
This script:

Sends multiple requests to the ALB.
Checks whether the expected version is returned.
Counts successful requests.
Counts failed requests.
Prints PASS/FAIL.
<img width="1357" height="687" alt="Screenshot 2026-09-14 193414" src="https://github.com/user-attachments/assets/862ec5df-d73c-4f8a-b47e-eb50cb842780" />

<img width="1360" height="712" alt="Screenshot 2026-09-14 193445" src="https://github.com/user-attachments/assets/9991da4b-fea5-4570-9e75-b787dd06225f" />

**test-canary.sh**
This script:

Sends multiple requests to the ALB.
Checks whether the response is Blue or Green.
Counts Blue responses.
Counts Green responses.
Counts failed responses.

This gave us evidence that weighted routing was actually sending requests to both versions.
<img width="1357" height="716" alt="Screenshot 2026-09-14 193511" src="https://github.com/user-attachments/assets/61aee661-7fd0-494f-87aa-4a74b634378b" />

<img width="1365" height="652" alt="Screenshot 2026-09-14 193530" src="https://github.com/user-attachments/assets/af52f061-ce00-4e9c-a237-04d6229be6ba" />

**Final Cleanup**

lastly, destroyed the environment:

terraform destroy

<img width="1364" height="694" alt="Screenshot 2026-09-14 193924" src="https://github.com/user-attachments/assets/578bb8d9-8e7a-49a9-8866-efe264441393" />

<img width="1365" height="717" alt="Screenshot 2026-09-14 194943" src="https://github.com/user-attachments/assets/116903a9-17cf-48f5-b27a-6dec6de9a92a" />


