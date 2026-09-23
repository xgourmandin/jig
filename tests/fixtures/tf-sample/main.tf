module "naming" {
  source = "./modules/naming"

  prefix = var.environment
  name   = "app"
}
