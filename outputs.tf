output "arn" {
  description = "arn of the created iam user"
  value       = aws_iam_user.iam_user.arn
}

output "id" {
  description = "id of the created iam user"
  value       = aws_iam_user.iam_user.unique_id
}

output "name" {
  description = "username of the created iam user"
  value       = aws_iam_user.iam_user.name
}

output "access_key_id" {
  description = "id of the access key"
  value       = aws_iam_access_key.iam_user.id
}

output "access_key" {
  description = "base64-encoded, encrypted access key of the user, use `base64 -d` to decrypt and `gpg -d encrypted.txt`"
  value       = aws_iam_access_key.iam_user.encrypted_secret
}
