# terraform/iam.tf

# This is the role the EC2 instances will assume.
# It allows them to be managed by SSM, and gives the CodeDeploy agent permissions.
resource "aws_iam_role" "ec2_instance_role" {
  name = "${var.project_name}-ec2-instance-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach the policy that allows the CodeDeploy agent to work
resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# Attach the policy that allows instances to be managed by Systems Manager (for debugging)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# This instance profile is what we attach to the EC2 instances in the launch template
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}

# This is the role that CodeDeploy itself will use to interact with EC2 and ALB
resource "aws_iam_role" "codedeploy_role" {
  name = "${var.project_name}-codedeploy-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

# Attach the main CodeDeploy policy to its role
resource "aws_iam_role_policy_attachment" "codedeploy_main" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# terraform/iam.tf (ADD THIS TO THE END)

# This policy grants permission to get objects from our CodePipeline S3 bucket
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy"
  description = "Allows reading from the CodePipeline artifact bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        Resource = "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
      },
      {
        Effect   = "Allow",
        Action   = "s3:ListBucket",
        Resource = aws_s3_bucket.codepipeline_artifacts.arn
      }
    ]
  })
}

# Attach the new S3 access policy to our EC2 instance role
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}


# Attach the policy that allows the EC2 instance to pull images from ECR
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# IAM ROLE FOR CODEPIPELINE
# -----------------------------------------------------------------------------
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "codepipeline_policy" {
  name   = "${var.project_name}-codepipeline-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["codestar-connections:UseConnection"],
        Resource = "arn:aws:codeconnections:us-east-1:235494795848:connection/a983ec3d-ebc4-4e40-8692-d693c421c2b5" # <-- PASTE YOUR GITHUB CONNECTION ARN HERE
      },
      {
        Effect   = "Allow",
        Action   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"],
        Resource = aws_codebuild_project.main.arn
      },
      {
        Effect   = "Allow",
        Action   = ["codedeploy:CreateDeployment", "codedeploy:GetDeploymentGroup"],
        Resource = aws_codedeploy_deployment_group.main.id
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

# -----------------------------------------------------------------------------
# IAM ROLE FOR CODEBUILD
# -----------------------------------------------------------------------------
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

# NOTE: In a real company, you would scope this down significantly.
# For a portfolio project, AdministratorAccess is acceptable to ensure it works.
resource "aws_iam_role_policy_attachment" "codebuild_admin" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}