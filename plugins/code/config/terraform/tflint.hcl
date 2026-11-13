# Fallback for modules without their own .tflint.hcl: every rule in the bundled Terraform ruleset.
# A project config is better; start from this one and add provider plugins (aws, azurerm, google).
plugin "terraform" {
  enabled = true
  preset  = "all"
}
