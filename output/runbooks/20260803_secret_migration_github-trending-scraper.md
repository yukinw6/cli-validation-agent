# Runbook: Cloud Run Secret Migration — github-trending-scraper

**Generated:** 2026-08-03T21:34:24+09:00
**Project:** tech-trend-1762180118
**Region:** asia-northeast1
**Service:** github-trending-scraper
**Operator account:** yuki.nw6@gmail.com

---

## 1. Current State

### Service Overview

| Item | Value |
|------|-------|
| Service URL | https://github-trending-scraper-5s6cl422ra-an.a.run.app |
| Service Account | github-scraper-sa@tech-trend-1762180118.iam.gserviceaccount.com |
| Status | Ready (generation 10) |
| Revision | github-trending-scraper-00010-vmz |

### Environment Variables (Plain Text)

All environment variables are currently stored as plain text values. No Secret Manager references exist.

| Variable Name | Current Value | Is Secret? |
|---------------|---------------|------------|
| `LOG_EXECUTION_ID` | `true` | No — boolean flag |
| `GCS_BUCKET_NAME` | `tech-trend-data-tech-trend-1762180118` | Low — bucket name |

**Note:** Neither variable contains high-sensitivity values (API keys, passwords, tokens). However, `GCS_BUCKET_NAME` exposes infrastructure naming conventions. Migrate per your org's security policy.

### Service Account Current IAM Roles

```
roles/bigquery.dataEditor
roles/bigquery.jobUser
roles/cloudsupport.techSupportEditor
roles/eventarc.eventReceiver
roles/run.invoker
roles/storage.objectCreator
```

**Missing for Secret Manager access:** `roles/secretmanager.secretAccessor`

### Secret Manager State

| Item | Value |
|------|-------|
| API enabled | YES |
| Existing secrets | 0 (none) |

---

## 2. Required Permissions

To perform the migration, the operator (`yuki.nw6@gmail.com`) needs:

| Permission | Purpose |
|------------|---------|
| `secretmanager.secrets.create` | Create new secrets |
| `secretmanager.versions.add` | Add secret values |
| `resourcemanager.projects.setIamPolicy` | Grant SA access to secrets |
| `run.services.update` | Update the Cloud Run service |

The Cloud Run Service Account needs:

| Role | Why |
|------|-----|
| `roles/secretmanager.secretAccessor` | Read secret values at runtime |

---

## 3. Step-by-Step Migration Procedure

### Step 0: Verify you can operate on this project

```bash
gcloud projects describe tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com
```

### Step 1: Create secrets in Secret Manager

Migrate each sensitive env var to a Secret Manager secret.

```bash
# Create GCS_BUCKET_NAME secret
echo -n "tech-trend-data-tech-trend-1762180118" | \
  gcloud secrets create github-scraper-gcs-bucket-name \
    --data-file=- \
    --replication-policy=user-managed \
    --locations=asia-northeast1 \
    --project=tech-trend-1762180118 \
    --account=yuki.nw6@gmail.com
```

Verify creation:
```bash
gcloud secrets describe github-scraper-gcs-bucket-name \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com
```

### Step 2: Grant the Service Account secretAccessor role

```bash
gcloud projects add-iam-policy-binding tech-trend-1762180118 \
  --member="serviceAccount:github-scraper-sa@tech-trend-1762180118.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --account=yuki.nw6@gmail.com
```

Alternatively, grant at the secret level (least-privilege):
```bash
gcloud secrets add-iam-policy-binding github-scraper-gcs-bucket-name \
  --member="serviceAccount:github-scraper-sa@tech-trend-1762180118.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com
```

### Step 3: Update the Cloud Run service to reference secrets

```bash
gcloud run services update github-trending-scraper \
  --region=asia-northeast1 \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com \
  --update-secrets=GCS_BUCKET_NAME=github-scraper-gcs-bucket-name:latest \
  --remove-env-vars=GCS_BUCKET_NAME
```

> **Note:** `LOG_EXECUTION_ID=true` is a non-sensitive boolean flag. It does not require migration to Secret Manager.

### Step 4: Confirm the new revision is serving traffic

```bash
gcloud run services describe github-trending-scraper \
  --region=asia-northeast1 \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com \
  --format="value(status.latestReadyRevisionName,status.conditions[0].status)"
```

---

## 4. Post-Check Commands

Run all of these after migration to verify correctness.

### 4-1. Confirm env var is now a secretKeyRef (not plain text)

```bash
gcloud run services describe github-trending-scraper \
  --region=asia-northeast1 \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com \
  --format="json" | python3 -c "
import json, sys
svc = json.load(sys.stdin)
containers = svc['spec']['template']['spec']['containers']
for c in containers:
    for ev in c.get('env', []):
        print(ev)
"
```

Expected: `GCS_BUCKET_NAME` should show `valueFrom.secretKeyRef`, not a plain `value`.

### 4-2. Confirm service is Ready

```bash
gcloud run services describe github-trending-scraper \
  --region=asia-northeast1 \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com \
  --format="value(status.conditions[0].type,status.conditions[0].status)"
```

Expected output: `Ready  True`

### 4-3. Confirm secret exists with a version

```bash
gcloud secrets versions list github-scraper-gcs-bucket-name \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com
```

Expected: at least one version with state `ENABLED`.

### 4-4. Confirm SA has secretAccessor

```bash
gcloud projects get-iam-policy tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com \
  --format=json | python3 -c "
import json, sys
data = json.load(sys.stdin)
sa = 'serviceAccount:github-scraper-sa@tech-trend-1762180118.iam.gserviceaccount.com'
for b in data.get('bindings', []):
    if sa in b.get('members', []):
        print(b['role'])
"
```

Expected: `roles/secretmanager.secretAccessor` appears in output.

---

## 5. Rollback Procedure

If the new revision fails, roll back to the previous revision with plain env vars.

### Step R-1: Identify the previous revision

```bash
gcloud run revisions list \
  --service=github-trending-scraper \
  --region=asia-northeast1 \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com \
  --sort-by=~creationTimestamp \
  --limit=5 \
  --format="table(name,status.conditions[0].status,creationTimestamp)"
```

The revision before migration (e.g., `github-trending-scraper-00010-vmz`) is the rollback target.

### Step R-2: Route 100% traffic to previous revision

```bash
gcloud run services update-traffic github-trending-scraper \
  --region=asia-northeast1 \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com \
  --to-revisions=github-trending-scraper-00010-vmz=100
```

### Step R-3: (Optional) Re-add plain env var and deploy

```bash
gcloud run services update github-trending-scraper \
  --region=asia-northeast1 \
  --project=tech-trend-1762180118 \
  --account=yuki.nw6@gmail.com \
  --set-env-vars=GCS_BUCKET_NAME=tech-trend-data-tech-trend-1762180118 \
  --remove-env-vars=""
```

### Step R-4: Remove secretAccessor grant (if desired)

```bash
gcloud projects remove-iam-policy-binding tech-trend-1762180118 \
  --member="serviceAccount:github-scraper-sa@tech-trend-1762180118.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --account=yuki.nw6@gmail.com
```

---

## 6. Notes and Observations

- **No secrets currently exist** in this project. Starting from a clean slate.
- `LOG_EXECUTION_ID=true` is a non-sensitive runtime flag and does not need migration.
- `GCS_BUCKET_NAME` embeds the project ID in its value (`tech-trend-1762180118`). Low-sensitivity, but included in the migration as it is infrastructure configuration.
- The service is built from a Cloud Functions v2 source (gcf-artifacts). Secret Manager references in Cloud Run env vars are fully supported for this runtime.
- Secret Manager API is already enabled — no API enablement step required.
- For least-privilege, prefer granting `secretAccessor` at the individual secret level rather than at the project level.

