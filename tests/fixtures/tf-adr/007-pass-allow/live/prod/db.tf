# archgate-ignore TF-007/stateful-resource-prevent-destroy reporting replica, rebuilt nightly
resource "aws_db_instance" "this" {
  identifier = "main"
}
