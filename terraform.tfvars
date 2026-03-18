project            = "dabom"
cloudflare_zone_id = ""  # TODO: Cloudflare Zone ID
tfc_organization   = "dabom"
monitor_eip        = ""  # 비워두면 OTEL 자동 비활성화. monitor 배포 후 업데이트.

# ─── Cloudflare R2 (Sensitive 값은 Terraform Cloud Variables 권장) ───
r2_endpoint    = ""  # https://<account-id>.r2.cloudflarestorage.com
r2_access_key  = ""
r2_secret_key  = ""

# ─── Slack ───
slack_webhook_url = ""  # Terraform Cloud Variables 권장 (Sensitive)

# ─── VAPID Web Push ───
vapid_public_key  = ""
vapid_private_key = ""
