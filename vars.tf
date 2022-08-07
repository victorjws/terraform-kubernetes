variable "region" {
  default     = "ap-northeast-2"
  description = "AWS region"
}

variable "availability_zone" {
  default     = "ap-northeast-2a"
  description = "AWS availability zone"
}

variable "profile" {
  default     = "aws-study"
  description = "AWS credentials"
}

variable "project_name" {
  default     = "kubernetes app"
  description = "project name"
}
