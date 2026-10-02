# archgate-ignore TF-007/stateful-resource-prevent-destroy
resource "aws_db_instance" "this" {
  identifier = "main"
}
