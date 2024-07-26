/**
 * # AWS Gitlab OIDC Provider Terraform Module
 *
 * ## Purpose
 * This module allows you to create a Gitlab OIDC provider for your AWS account, that will allow Gitlab pipelines to securely authenticate against the AWS API using an IAM role
 *
*/

data "tls_certificate" "gitlab" {
  url = var.gitlab_tls_url
}

resource "aws_iam_openid_connect_provider" "this" {
  count = var.create_oidc_provider ? 1 : 0

  client_id_list  = var.aud_value
  thumbprint_list = [data.tls_certificate.gitlab.certificates[0].sha1_fingerprint]
  url             = var.url
}

resource "aws_iam_role" "this" {
  count                = var.create_oidc_provider && var.create_oidc_role ? 1 : 0
  name                 = var.role_name
  description          = var.role_description
  max_session_duration = var.max_session_duration
  assume_role_policy   = join("", data.aws_iam_policy_document.this[*].json)
  tags                 = var.tags

  depends_on = [aws_iam_openid_connect_provider.this]
}

resource "aws_iam_role_policy_attachment" "attach" {
  count = var.create_oidc_role ? length(var.oidc_role_attach_policies) : 0

  policy_arn = var.oidc_role_attach_policies[count.index]
  role       = join("", aws_iam_role.this[*].name)

  depends_on = [aws_iam_role.this]
}

data "aws_iam_policy_document" "this" {

  dynamic "statement" {
    for_each = aws_iam_openid_connect_provider.this

    content {
      actions = ["sts:AssumeRoleWithWebIdentity"]
      effect  = "Allow"

      condition {
        test     = "StringLike"
        values   = var.project_paths
        variable = "${join("", aws_iam_openid_connect_provider.this[*].url)}:${var.match_field}"
      }

      principals {
        identifiers = [statement.value.arn]
        type        = "Federated"
      }
    }
  }
}
