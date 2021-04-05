#
# iam-user-gcc
# ------------
# this module assists in creating an iam user for gcc
#

# ref https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}

# ref https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user
resource "aws_iam_user" "iam_user" {
  name                 = var.username
  force_destroy        = true
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/GCCIAccountBoundary"

  tags = {
    applied_with = "terraform"
    email        = var.email
    name         = var.name
    purpose      = var.purpose
  }
}

# ref https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key
resource "aws_iam_access_key" "iam_user" {
  user    = aws_iam_user.iam_user.name
  pgp_key = var.pgp_key
}
