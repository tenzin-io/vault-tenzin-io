#
# Secrets store for GitHub repos 
#
resource "vault_mount" "github" {
  path        = "github"
  type        = "kv"
  options     = { version = "2" }
  description = "Secret store for GitHub repositories"
}

resource "vault_kv_secret_backend_v2" "github" {
  mount        = vault_mount.github.path
  max_versions = 15
  cas_required = false
}

locals {
  secret_paths = ["cloudflare", "artifactory"]
}

resource "vault_policy" "github" {
  for_each = toset(local.secret_paths)
  name     = "github-policy-${each.value}"
  policy = templatefile("${path.module}/files/github_secrets_policy.hcl", {
    mount_path = "${vault_mount.github.path}/${each.value}"
  })
}

#
# JWT auth method for GitHub repos
#
resource "vault_jwt_auth_backend" "github" {
  description        = "GitHub JWT authentication method"
  path               = "jwt"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"
}

resource "vault_jwt_auth_backend_role" "github_actions" {
  for_each          = { for i, r in var.allowed_github_repos : r.claims.repository => r }
  backend           = vault_jwt_auth_backend.github.path
  role_name         = "actions-runner-role-${md5(each.key)}"
  token_policies    = [for i, s in each.value.secret_paths : format("github-policy-%s", s)]
  bound_claims      = each.value.claims
  bound_claims_type = "string"
  user_claim        = "sub"
  role_type         = "jwt"
}