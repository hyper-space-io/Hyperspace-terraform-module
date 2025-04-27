# resource "null_resource" "vcs_repo_reattach" {
#   triggers = {
#     # Trigger on any change to the workspace or VCS configuration
#     timestamp    = timestamp()
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       # Detach VCS repo
#       curl -s -H "Authorization: Bearer ${var.tfc_agent_token}" \
#         -H "Content-Type: application/vnd.api+json" \
#         -X PATCH \
#         "https://app.terraform.io/api/v2/workspaces/${tfe_workspace.app.id}" \
#         -d '{"data":{"type":"workspaces","attributes":{"vcs-repo":null}}}'

#       # Wait a moment for the detach to complete
#       sleep 5

#       # Reattach VCS repo
#       curl -s -H "Authorization: Bearer ${var.tfc_agent_token}" \
#         -H "Content-Type: application/vnd.api+json" \
#         -X PATCH \
#         "https://app.terraform.io/api/v2/workspaces/${tfe_workspace.app.id}" \
#         -d '{"data":{"type":"workspaces","attributes":{"vcs-repo":{"identifier":"${local.hyperspace_org_name}/Hyperspace-terraform-module","branch":"${var.argocd_vcs_configuration.branch}","oauth-token-id":null,"github-app-installation-id":null}}}}'
#     EOT
#   }

#   depends_on = [tfe_workspace.app]
# } 