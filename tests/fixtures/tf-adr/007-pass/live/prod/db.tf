resource "aws_db_instance" "this" {
  identifier = "main"

  lifecycle {
    prevent_destroy = true
  }
}
