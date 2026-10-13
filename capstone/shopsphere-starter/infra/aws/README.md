# AWS Terraform (Days 26-29)

Azure remains the default track. These folders are the AWS equivalent of the same ShopSphere product.

| Folder | Day | Purpose |
|:--|:--|:--|
| `org/` | 26 | Organizations + one SCP example |
| `modules/eks/` | 27 | EKS via Terraform |
| `modules/network/` | 28 | VPC + IRSA / Pod Identity inputs |
| `backend/` | 29 | S3 + DynamoDB lock or S3 native lock |
| `environments/dev/` | 27-29 | Dev apply |

Estimated EKS session: **USD 2.00-5.00**. Destroy the same day. Local fallback: `kind` plus IRSA annotation YAML. LocalStack can stub S3. LocalStack does not replace Organizations.
