# ECR repository for the sre-reference-app image. Empty by default; first apply
# uses var.container_image (public nginx) so the stack works end-to-end before
# you push your own image.
#
# When ready, push your image:
#   aws ecr get-login-password --region us-west-2 | \
#     docker login --username AWS --password-stdin <acct>.dkr.ecr.us-west-2.amazonaws.com
#   docker build -t sre-reference-app .
#   docker tag sre-reference-app:latest <acct>.dkr.ecr.us-west-2.amazonaws.com/sre-reference-app:latest
#   docker push <acct>.dkr.ecr.us-west-2.amazonaws.com/sre-reference-app:latest
#
# Then set container_image = "<acct>.dkr.ecr.us-west-2.amazonaws.com/sre-reference-app:latest"
# in terraform.tfvars and re-apply.

resource "aws_ecr_repository" "app" {
  provider             = aws.workloads_dev
  name                 = "sre-reference-app"
  image_tag_mutability = "MUTABLE" # IMMUTABLE is stricter for prod; MUTABLE keeps "latest" usable

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256" # KMS would be tighter; AES256 is free, no key to manage
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  provider   = aws.workloads_dev
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images, delete the rest"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
