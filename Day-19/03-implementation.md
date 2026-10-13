# Day 19 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 19 teaches the software supply chain. The old lab stopped at `sha256sum` and `actions/checkout@v4`. This lab adds **Gitleaks**, **Syft SBOM**, **Trivy**, **Cosign**, and a **Kyverno** policy that denies `:latest`.

Work in **your ShopSphere repository**.

---

## Goal

Scan the repo for secrets. Generate an SBOM of `app/`. Scan the image (or the filesystem) with Trivy. Sign and verify with Cosign (key pair is enough). Add a Kyverno ClusterPolicy. Pin GitHub Actions by tag.

Time box: 70 to 90 minutes.

---

## Capstone stage

| Path | Adds |
|:--|:--|
| `.github/workflows/supply-chain.yml` | gitleaks, Syft, Trivy |
| `sbom/app.syft.json` | generated locally, you may gitignore it |
| `policies/deny-latest.yaml` | Kyverno |
| `docs/day-19-supply-chain.md` | digests and verify output |

---

## What you need

```bash
gitleaks version
syft version
trivy --version
cosign version
sha256sum --version
```

Pins that exist as of 2026-10-13:

| Tool | Version |
|:--|:--|
| Gitleaks | 8.24.0 (executed in the authoring VM) |
| Syft | 1.19.0 (executed) |
| Trivy | 0.58.1 |
| Cosign | 2.4.3 |

Install from those GitHub release pages. Docker is optional. Trivy can scan a filesystem without an image.

---

## Cost

Local scanners: **USD 0.00**. Cosign key pair is local. A public registry pull of `nginx:1.27` uses your network, not a cloud bill. Do not push signatures to a paid registry unless you will delete them.

---

## Steps

1. Gitleaks.

```bash
gitleaks detect --source . --no-git --verbose
```

Expected: no leaks, or a finding you must fix. Do not commit `.env`.

Plant a break (see Break and fix) only in a file you will delete.

2. Hash the artifact the old lab already taught. Keep it.

```bash
sha256sum app/main.py | tee docs/main.py.sha256
sha256sum -c docs/main.py.sha256
```

Expected: `OK`.

3. SBOM with Syft 1.19.0.

```bash
syft dir:app -o syft-json=sbom/app.syft.json -o table
```

On a stdlib-only app the table may say **No packages discovered**. That is still an SBOM. Record the command. If you have `requirements.txt` with a pin later, the table grows.

4. Trivy filesystem scan.

```bash
trivy fs --scanners vuln,secret,misconfig app
```

If Trivy is missing, write the command and record `trivy not executed`. Do not invent flags. `trivy fs` is real.

If Docker works:

```bash
docker build -t shopsphere-api:dev -f app/Dockerfile app
trivy image shopsphere-api:dev
```

5. Cosign key pair (local, not Fulcio, so you do not need an identity token).

```bash
mkdir -p .cosign
cosign generate-key-pair --output-key-prefix .cosign/shopsphere
# writes .cosign/shopsphere.key and .cosign/shopsphere.pub
echo "signed by shopsphere" > /tmp/shopsphere-artifact
cosign sign-blob --key .cosign/shopsphere.key --output-signature /tmp/shopsphere-artifact.sig /tmp/shopsphere-artifact
cosign verify-blob --key .cosign/shopsphere.pub --signature /tmp/shopsphere-artifact.sig /tmp/shopsphere-artifact
```

Expected verify: `Verified OK`. Add `.cosign/*.key` to `.gitignore`. You may commit the `.pub` file.

6. Kyverno policy. `policies/deny-latest.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: deny-latest-tag
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: deny-latest
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "Do not use the latest tag."
        pattern:
          spec:
            containers:
              - image: "!*:latest"
```

Apply only if Kyverno is installed. Install is optional today:

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace
kubectl apply -f policies/deny-latest.yaml
```

If Helm is missing, keep the YAML. Day 16 already used Helm.

7. Workflow. `.github/workflows/supply-chain.yml` — pin actions by tag. Use `gitleaks/gitleaks-action@v2` only if you accept that action's latest v2; prefer a raw install of 8.24.0 in a step so the version is exact.

```yaml
name: supply-chain
on:
  pull_request:
  push:
    branches: [main]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: syft
        uses: anchore/sbom-action@v0
        with:
          path: app
          format: syft-json
```

`anchore/sbom-action@v0` and `gitleaks/gitleaks-action@v2` are real actions. In a company repo, pin the commit SHA.

---

## Verify

- `sha256sum -c` printed `OK`.
- `gitleaks version` is 8.24.0 or you recorded the version you ran.
- `syft dir:app` wrote a file (even if empty of packages).
- Cosign verify printed `Verified OK`, or you recorded `cosign not installed`.
- `policies/deny-latest.yaml` exists.
- No private key is in Git.

---

## Break and fix

### Failure 1 — planted secret

```bash
printf '%s\n' '-----BEGIN PRIVATE KEY-----' 'MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCv2lrjYi' '-----END PRIVATE KEY-----' > /tmp/leak.env
gitleaks detect --source /tmp/leak.env --no-git
```

Expected: Gitleaks 8.24.0 prints `leaks found: 1` and exits 1. Delete the file. Do not commit it. Diagnose with Gitleaks, not with `grep` alone. A short `AKIA...` string may not match a rule. A PEM header does.

### Failure 2 — checksum mismatch

```bash
echo changed >> app/main.py
sha256sum -c docs/main.py.sha256 || true
```

Expected: `FAILED`. Restore the file (`git checkout -- app/main.py`) and re-hash.

---

## Stretch

- `cosign sign` an image digest on GHCR if you have a throwaway repo.
- Kyverno `verifyImages` with the Cosign public key.

---

## Clean up

```bash
rm -f /tmp/shopsphere-artifact /tmp/shopsphere-artifact.sig /tmp/leak.env
rm -f .cosign/shopsphere.key   # keep the pub if you want
```

Do not leave a private key in chat or in Git.

---

## Interview story

**Situation:** ShopSphere CI only hashed a file and pinned `actions/checkout@v4`. **Task:** Put secret scan, SBOM, image scan, and signature on the path to Prod. **Action:** I ran Gitleaks 8.24.0, Syft 1.19.0 on `app/`, Trivy `fs`, and Cosign `sign-blob` / `verify-blob` with a local key pair. I added a Kyverno policy that denies `:latest`. I planted a PEM private-key header and watched Gitleaks 8.24.0 exit 1, then I deleted the file. **Result:** I can name each gate and I do not call a checksum a complete supply chain.

---

## Self-score checklist

- [ ] Gitleaks ran (or I recorded why not).
- [ ] Syft wrote an SBOM file.
- [ ] Checksum verify works and I broke it once.
- [ ] Cosign verify worked, or I recorded `not executed`.
- [ ] Kyverno YAML is in Git.
- [ ] No private key or planted secret remains.

**Executed in the authoring VM:** Gitleaks 8.24.0, Syft 1.19.0, `sha256sum`. **Not executed:** Trivy binary install, Cosign, Kyverno Helm, `trivy image`.
