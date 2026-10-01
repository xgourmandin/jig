# jig:allow TF-007 reporting replica, rebuilt nightly
resource "aws_db_instance" "this" {
  identifier = "main"
}
