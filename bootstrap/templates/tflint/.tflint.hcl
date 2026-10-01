# Jig tflint config (ADR TF-003). tflint's built-in terraform ruleset needs no plugin download.
# Run with: tflint --recursive
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
  style   = "flexible"
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}
