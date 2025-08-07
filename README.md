# Automated Web Application Deployment Using Terraform and AWS CI/CD Stack

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)

## 📖 Project Overview

In this project, I've built a comprehensive, production-grade CI/CD pipeline on AWS for a containerized web application. My goal was to create a system that automatically builds and deploys a Python Flask application whenever new code is pushed to the main branch.

The entire cloud environment, from the foundational network to the CI/CD pipeline itself, is defined and provisioned using Terraform. This demonstrates a true Infrastructure as Code (IaC) approach and adheres to modern DevOps and SRE principles like full automation, high availability, and idempotency.

---

## 🏛️ Final Architecture

The final architecture is a seamless, event-driven workflow that requires zero manual intervention after the initial setup.

**CI/CD Flow Diagram:**
```
+-----------+     git push     +----------+      Triggers      +----------------+
| Developer |  ------------->  | GitHub   |  --------------->  | AWS            |
|           |                  | (main)   |                    | CodePipeline   |
+-----------+                  +----------+                    +----------------+
                                                                       |
                                                                       | (Source Artifact)
                                                                       V
+------------------------------------+                             +----------------+
| AWS CodeBuild                      |                             | AWS            |
|------------------------------------|                             | CodeDeploy     |
| 1. Install Dependencies (Terraform)|                             +----------------+
| 2. Login to Docker Hub & ECR       |                                     |
| 3. Build Docker Image (Flask App)  |                                     | (Deploy)
| 4. Terraform Apply (Verify Infra)  |                                     |
| 5. Push Docker Image to ECR        |  <------ (Build Artifact) ------    V
| 6. Generate Deploy Artifacts       |                               +----------------+
+------------------------------------+                               | Auto Scaling   |
                                                                     | Group (EC2s)   |
                                                                     +----------------+
                                                                             ^
                                                                             | (Health Checks)
                                                                             |
      +-------------+        Serves Traffic       +--------------------------+
      | End User    |  <-----------------------   | Application Load Balancer|
      +-------------+                             +--------------------------+

```

### Key Infrastructure Components (All managed by Terraform):
* **Networking:** A custom VPC with public subnets across two Availability Zones for high availability.
* **Compute:** An Auto Scaling Group managing two EC2 instances, ensuring the application is resilient to instance failure.
* **Load Balancing:** An Application Load Balancer (ALB) to distribute traffic and perform health checks.
* **Security:** Tightly scoped Security Groups allowing public web traffic only to the ALB, and only ALB traffic to the EC2 instances.
* **Container Registry:** A private Amazon ECR repository to securely store the application's Docker images.
* **CI/CD Automation:** An AWS CodePipeline, CodeBuild project, and CodeDeploy application, all defined as code.
* **Storage & State:** An S3 bucket for pipeline artifacts and a separate, versioned S3 bucket for the Terraform remote state, enabling team collaboration.
* **Security & Credentials:** Finely-tuned IAM Roles for each service and integration with AWS Secrets Manager to securely handle Docker Hub credentials.

---

## 🌟 Project Evolution & Challenges Solved

This project was a realistic exercise in iterative development. My initial goal was met, but I significantly improved the architecture to meet professional standards.

1.  **Initial Manual Setup:** My first successful deployment involved provisioning the infrastructure with Terraform and then manually creating the CodePipeline in the AWS Console. I quickly realized this "ClickOps" step was a bottleneck and violated the principle of 100% automation.

2.  **Transition to Full IaC:** I refactored the project to include the `aws_codepipeline` and `aws_codebuild_project` resources directly in my Terraform code. This transformed the project into a true one-command deployment (`terraform apply`), making it fully repeatable, version-controlled, and professional.

3.  **Debugging Real-World Issues:** Throughout the development, I encountered and solved several critical, real-world issues:
    * **IAM Permissions:** I debugged and corrected multiple `AccessDenied` errors by refining IAM policies for the CodeBuild and EC2 Instance Roles, diving deep into the specific API calls each service needed to make.
    * **Build Environment Dependencies:** I enhanced the `buildspec.yml` to include an `install` phase to robustly install missing tools like `unzip` and `terraform` in the build container.
    * **Docker Hub Rate Limiting:** When the build started failing due to anonymous pull limits from Docker Hub, I implemented a professional solution by integrating **AWS Secrets Manager** to securely store and use my Docker Hub credentials.
    * **Deployment Health Checks:** The deployment stage repeatedly failed due to `HEALTH_CONSTRAINTS`. I used SSM Session Manager to connect to the EC2 instances and discovered the Flask development server was running on the wrong port. I refactored the `Dockerfile` to use a production-grade `gunicorn` server, explicitly binding to the correct port (80).
    * **Stateful Deployments:** I fixed a container name conflict during deployments by making the `stop_server.sh` script more robust, ensuring it could clean up old, stopped containers from previous failed runs.

---

## ✅ Prerequisites

* An AWS Account with Administrator-level access.
* A GitHub Account.
* A Docker Hub Account.
* Locally installed **Terraform** and **AWS CLI**.

---

## 🚀 Setup & Deployment

This project is deployed with a single command after a one-time setup.

### 1. One-Time Setup
* **Create GitHub Connection:** In the AWS Console (CodePipeline -> Settings -> Connections), create a connection to your GitHub account and **copy its ARN**.
* **Create Docker Hub Secret:** In AWS Secrets Manager, store your Docker Hub credentials in a secret named `dockerhub-credentials` and **copy its ARN**.
* **Create Terraform State Bucket:** Manually create a unique, versioned S3 bucket for the Terraform state file.

### 2. Configure and Deploy
* Update the `backend "s3"` block in `terraform/main.tf` with your state bucket name.
* Create a `terraform/terraform.tfvars` file with your unique values:
    ```tfvars
    github_connection_arn = "<YOUR_GITHUB_CONNECTION_ARN>"
    github_repo_id        = "your-github-username/your-repo-name"
    ```
* From the `terraform/` directory, run:
    ```bash
    terraform init
    terraform apply
    ```
This command will build the entire stack. The pipeline will be created and will automatically trigger its first run.

---

## 🔙 Rollback Strategy

* **Automatic:** CodeDeploy is configured to automatically roll back to the previous stable version if ALB health checks fail on a new deployment.
* **Manual:** For logical bugs, a `git revert` followed by a `git push` will trigger the pipeline to redeploy the last known good version.

---

## 🧹 Cleanup

To destroy all project resources and stop all costs, run a single command from the `terraform/` directory:
```bash
terraform destroy
```
You will also need to manually delete the S3 state bucket, the GitHub connection, and the Docker Hub secret from the AWS Console.
