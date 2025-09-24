# Video on Demand on AWS - Terraform Implementation
# Main configuration file

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
  backend "s3" {
    bucket         = "tf-state-store-121485"
    key            = "vod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-state-lock-121485"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      SolutionId = "SO0021"
      Project    = "VideoOnDemand"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Random UUID for anonymized metrics
resource "random_uuid" "solution_uuid" {}

# Local values
locals {
  solution_id      = "SO0021"
  solution_version = "v6.1.13"
  stack_name       = var.stack_name

  # Conditional logic
  enable_media_package = var.enable_media_package == "Yes"
  frame_capture        = var.frame_capture == "Yes"
  enable_sns           = var.enable_sns == "Yes"
  enable_sqs           = var.enable_sqs == "Yes"

}

# Modules
module "storage" {
  source = "./modules/storage"

  stack_name = local.stack_name
  glacier    = var.glacier
}

module "cloudfront" {
  source = "./modules/cloudfront"

  stack_name         = local.stack_name
  destination_bucket = module.storage.destination_bucket
  logs_bucket        = module.storage.logs_bucket
}

module "lambda" {
  source = "./modules/lambda"

  stack_name         = local.stack_name
  solution_version   = local.solution_version
  source_bucket      = module.storage.source_bucket
  destination_bucket = module.storage.destination_bucket
  dynamodb_table     = module.database.dynamodb_table
  sns_topic          = local.enable_sns ? module.messaging.sns_topic : null
  sqs_queue = {
    arn = module.messaging.sqs_queue_arn
    url = module.messaging.sqs_queue_url
  }
  cloudfront_domain               = module.cloudfront.domain_name
  frame_capture                   = local.frame_capture
  glacier                         = var.glacier
  # Individual resolution-specific templates are now selected dynamically by the profiler Lambda
  # No need to pass template names as they are selected based on source video resolution
  enable_media_package            = local.enable_media_package
  enable_sns                      = local.enable_sns
  enable_sqs                      = local.enable_sqs
  accelerated_transcoding         = var.accelerated_transcoding
  mediapackage_group_id           = module.media_resources.mediapackage_group_id
  mediapackage_domain_name        = module.media_resources.mediapackage_group_domain_name
}

module "database" {
  source = "./modules/database"

  stack_name = local.stack_name
}

module "messaging" {
  source = "./modules/messaging"

  stack_name  = local.stack_name
  admin_email = var.admin_email
  enable_sns  = local.enable_sns
}

module "step_functions" {
  source = "./modules/step_functions"

  stack_name                = local.stack_name
  lambda_functions          = module.lambda.lambda_functions
  step_functions_lambda_arn = module.lambda.step_functions_lambda_arn
  enable_media_package      = local.enable_media_package
}

module "media_resources" {
  source = "./modules/media_resources"

  stack_name                 = local.stack_name
  aws_region                 = var.aws_region
  source_bucket_arn          = module.storage.source_bucket.arn
  destination_bucket_arn     = module.storage.destination_bucket.arn
  enable_media_package       = local.enable_media_package
  cloudfront_distribution_id = module.cloudfront.distribution_id
}

# MediaConvert endpoint is obtained directly in the template creation script


module "events" {
  source = "./modules/events"

  stack_name            = local.stack_name
  error_handler_lambda  = module.lambda.error_handler_lambda_arn
  step_functions_lambda = module.lambda.step_functions_lambda_arn
}

module "s3_notifications" {
  source = "./modules/s3_notifications"

  source_bucket_id          = module.storage.source_bucket.id
  source_bucket_arn         = module.storage.source_bucket.arn
  step_functions_lambda_arn = module.lambda.step_functions_lambda_arn
  workflow_trigger          = var.workflow_trigger
}
