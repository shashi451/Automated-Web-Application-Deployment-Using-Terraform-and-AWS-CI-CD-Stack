# CODEBUILD PROJECT
# -----------------------------------------------------------------------------
resource "aws_codebuild_project" "main" {
  name          = "${var.project_name}-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "15" # in minutes

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0" # Using Amazon Linux 2 image
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true # Required for building Docker images
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# -----------------------------------------------------------------------------
# CODEPIPELINE
# -----------------------------------------------------------------------------
resource "aws_codepipeline" "main" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      configuration = {
        ConnectionArn    = "arn:aws:codeconnections:us-east-1:235494795848:connection/a983ec3d-ebc4-4e40-8692-d693c421c2b5" # <-- PASTE YOUR GITHUB CONNECTION ARN HERE
        FullRepositoryId = "shashi451/Automated-Web-Application-Deployment-Using-Terraform-and-AWS-CI-CD-Stack" # e.g., shashi451/Automated-Web-Application...
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.main.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildArtifact"]
      configuration = {
        ApplicationName     = aws_codedeploy_app.main.name
        DeploymentGroupName = aws_codedeploy_deployment_group.main.deployment_group_name
      }
    }
  }
}