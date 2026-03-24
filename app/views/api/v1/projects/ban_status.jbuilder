json.id @project.id
json.banned @project.deleted_at.present?
json.shadow_banned @project.shadow_banned
json.shadow_banned_at @project.shadow_banned_at
json.shadow_banned_reason @project.shadow_banned_reason
