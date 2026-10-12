# Day 10 — Terraform State & Enterprise Workflow

This Day uses three files. Read them in this order.

1. [01-concepts.md](01-concepts.md) — lesson content (this file)
2. [02-questions-and-answers.md](02-questions-and-answers.md) — practice items, each with a model answer
3. [03-implementation.md](03-implementation.md) — hands-on lab

## What you will learn

Terraform State is one of the most important Terraform concepts for a Senior/Lead DevOps engineer because it affects collaboration, security, ownership, drift, and production safety.

By the end of this lesson, you should be able to explain why Terraform needs state and how Terraform uses it. You should be able to explain why teams move state to a remote backend and why state locking matters. Finally, you should be able to explain how enterprises divide state between teams, workloads, and environments, and how to respond safely when infrastructure drifts from the Terraform configuration.

---

## Part 1 — Understand Terraform State

1. Why does Terraform need State?

Terraform uses configuration to describe the infrastructure you want, but configuration alone does not tell Terraform everything about the infrastructure it is already managing. Terraform State keeps a record of the resources Terraform knows about and the relationship between those resources and your configuration. During `terraform plan`, Terraform uses the configuration, the state, and the real infrastructure to work out what has changed and what action is required. Without state, Terraform would have a much harder time to decide whether an existing resource matches a particular configuration block.

**Remember:** State is Terraform's record of the infrastructure it manages.

2. What is inside the State?

A state file contains information Terraform needs to track managed resources, including resource addresses, provider information, resource identifiers, attributes, and relationships between resources. Depending on the resources and configuration, state can also contain sensitive values. This is why you should not treat a state file like an ordinary source-code file or commit it casually to a Git repository.

**Remember:** Terraform State can contain sensitive infrastructure information, so protect it.

3. How does `terraform plan` use State?

When you run `terraform plan`, Terraform does not simply read your `.tf` files and create everything again. It compares your desired configuration with its known state and the current infrastructure returned by the provider. If someone changes a resource outside Terraform, Terraform can detect that difference and may propose a change to bring the infrastructure back toward the configuration. This is the foundation of Terraform's ability to manage infrastructure declaratively.

4. What is Drift?

Drift occurs when the real infrastructure no longer matches what Terraform expects from its configuration and state. A common example: an engineer changes a resource manually through the cloud portal after Terraform created it. During a later plan, Terraform may detect the difference and propose an update. Drift is important in production because unmanaged manual changes make infrastructure harder to understand, audit, reproduce, and troubleshoot.

5. How do you mitigate Drift?

When Terraform detects drift, the first step should not automatically be to run `terraform apply`. First determine what changed, why it changed, and whether the manual change was intentional. Run `terraform plan` to understand the difference, then choose the appropriate response. If the manual change was accidental or should not exist, Terraform can usually reconcile the resource back to the configuration. If the manual change was intentional and should become the new desired state, update the Terraform configuration to represent it and then apply the configuration. If another system legitimately manages a particular attribute, design the Terraform configuration so that Terraform does not continuously overwrite that attribute.

**Remember:** Detect drift, investigate it, then decide whether to reconcile, codify, or deliberately manage the difference.

---

## Part 2 — Move from Local State to Team State

6. What is Local State?

By default, Terraform stores state locally in a `terraform.tfstate` file in the working directory. Local state is convenient for learning and small personal projects because there is no additional backend to configure. The problem appears when several engineers or CI/CD pipelines manage the same infrastructure. Each person could otherwise end up with a different copy of state.

7. Why use Remote State?

Remote State stores the Terraform state in a shared backend rather than on an individual engineer's laptop. This gives the team a common state location that both engineers and CI/CD systems can access. In a real organization, teams normally combine remote state with access control, encryption, versioning or recovery capabilities, and locking. The state then becomes a controlled shared resource rather than an unmanaged file.

8. What is a Terraform Backend?

A backend determines where Terraform stores state and how Terraform accesses that state. The backend is therefore more than "remote storage"; it is the mechanism Terraform uses to persist and retrieve state. In an enterprise setup, backend design should consider security, access control, recovery, collaboration, and locking rather than simply choosing somewhere to upload a file.

9. Why is State Locking important?

State locking prevents multiple Terraform operations from modifying the same state at the same time when the backend supports locking. Imagine one engineer is running `terraform apply` while another engineer or a CI/CD pipeline starts another apply against the same state. Without appropriate locking, concurrent operations can interfere with each other and potentially produce an inconsistent state or unexpected infrastructure changes. Locking therefore protects the shared state during operations; it does not replace code review or deployment controls.

**Remember:** Remote State enables collaboration; State Locking protects concurrent operations.

---

## Part 3 — Enterprise State Design

10. Why shouldn't an enterprise use one giant State file?

A small lab can manage many resources from one state file, but a large organization may have hundreds of resources owned by different teams. One state for everything creates a large ownership and access boundary. Many people get access to state that they do not actually need, plans become larger, and an error in one part of the infrastructure can have a wider blast radius. When you split state, the organization gets clearer ownership boundaries and less unnecessary coupling.

11. Why separate State by Team or Workload?

Different teams should normally have access only to the state they need to manage. For example, the Network team may manage VNet/VPC, subnets, routing, and security infrastructure, while an Application team manages resources belonging to its application. The Application team does not need broad access to the Network team's state just because its application depends on the network. This separation supports least privilege and reduces the blast radius of mistakes.

12. Why separate State by Environment?

Dev, UAT, and Production should normally have separate state boundaries because they have different risk levels, ownership requirements, credentials, and change controls. A production state should not be casually shared with development workflows. Separating environments also makes it easier to apply different permissions and approval processes while keeping the infrastructure design consistent.

13. How should State access follow Least Privilege?

Terraform state is an infrastructure asset, so access to it should be granted according to the work someone actually needs to perform. A Network engineer who manages network state does not automatically need access to application state. A developer should not receive production state access merely because they can view application code. In enterprise environments, backend permissions, cloud IAM/RBAC, CI/CD identities, and environment controls should work together to restrict state access.

**Remember:** Least privilege applies to Terraform State too.

14. How does State design reduce Blast Radius?

Blast radius describes how much infrastructure one change or failure can potentially affect. A Terraform state that contains an entire enterprise has a very large blast radius, because one plan or apply operates against a huge collection of resources. Smaller, well-designed state boundaries reduce the amount of infrastructure exposed to one Terraform operation and make ownership, review, troubleshooting, and recovery easier.

**Remember:** Smaller state boundaries generally mean smaller operational blast radius.

---

## Part 4 — Safe Terraform Operations

15. Why use a Saved Plan?

In a controlled production workflow, Terraform generates a plan, the team reviews it, and Terraform applies that exact plan. This is useful because the team can inspect the proposed infrastructure changes before execution. A later apply then cannot recalculate a potentially different plan. A CI/CD pipeline can therefore build the plan, publish it for review or approval, and then apply the approved plan.

**Remember:** Plan first, review the change, then apply the approved change.

16. What does `terraform import` solve?

Import allows Terraform to begin managing infrastructure that already exists outside Terraform. Import associates the existing infrastructure with a Terraform resource address, but it does not automatically give you a complete, production-ready Terraform configuration. You still need appropriate configuration and should run a plan to understand what Terraform believes the desired state should be.

17. Why should Terraform run through CI/CD in Production?

Production infrastructure should not depend on an engineer's laptop as the primary execution environment. A CI/CD pipeline provides a controlled identity, consistent Terraform version and tooling, policy checks, plan review, approvals, audit history, and a repeatable execution path. A typical workflow is code change → validation → plan → review/approval → apply → verification.

---

## Part 5 — Terraform and Bicep

18. How does Bicep work differently from Terraform?

Terraform and Bicep are both Infrastructure as Code tools, but they manage infrastructure differently. Terraform keeps its own state file to map Terraform resources to real infrastructure and uses that state during planning and changes. Bicep is Azure-specific: the tooling compiles a Bicep file into an ARM template, and Azure Resource Manager runs the deployment with Azure's resource model. Bicep therefore does not keep a separate Terraform-style state file. The simple mental model is: Terraform uses configuration plus Terraform State and a provider. Bicep code compiles to ARM and deploys through Azure Resource Manager.

This difference also affects operations. With Terraform, state becomes an important team-management concern: where it is stored, who can access it, how it is locked, and how it is divided between workloads and environments. With Bicep, Azure Resource Manager and Azure's access-control model handle deployment state and resource management. Bicep is therefore closely integrated with Azure, while Terraform provides a common IaC model across multiple cloud providers.

**Core Mental Model**

**Terraform configuration describes what you want.  
Terraform State records what Terraform manages.  
The provider tells Terraform what exists.  
Plan compares these to determine the required change.  
Remote State allows teams to share that state.  
Locking protects concurrent operations.  
State boundaries define ownership and reduce blast radius.  
CI/CD provides controlled production execution.  
Bicep uses Azure Resource Manager rather than a Terraform-style state file.**

**Cleanup**

If this was only a lab, destroy the resources you created:

```bash
terraform destroy
```

After destruction, verify that the lab resources no longer exist and remove any temporary local files that are no longer needed.
