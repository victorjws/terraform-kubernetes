resource "local_sensitive_file" "ssh_key_pem" {
  filename        = "${aws_key_pair.ssh_key_pair.key_name}.pem"
  content         = tls_private_key.pk.private_key_pem
  file_permission = "0400"
}