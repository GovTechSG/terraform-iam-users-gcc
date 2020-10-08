#
# iam-user-gcc
# ------------
# this module assists in creating an iam user for gcc
#

# ref: https://www.terraform.io/docs/providers/aws/d/caller_identity.html
data "aws_caller_identity" "current" {}

# ref https://www.terraform.io/docs/providers/aws/r/iam_user.html
resource "aws_iam_user" "iam_user" {
  name                 = var.username
  force_destroy        = true
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/GCCIAccountBoundary"

  tags = {
    applied_with = "terraform"
    email        = var.email
    name         = var.name
    purpose      = var.purpose
    module_url   = "https://gitlab.ci.mcf.sh/wsg/ops-aws/tree/master/modules/iam-user-gcc"
  }
}

# ref https://www.terraform.io/docs/providers/aws/r/iam_access_key.html
resource "aws_iam_access_key" "iam_user" {
  user    = aws_iam_user.iam_user.name
  pgp_key = var.pgp_key
}
