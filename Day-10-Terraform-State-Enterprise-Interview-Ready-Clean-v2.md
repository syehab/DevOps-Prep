# Day 10 — Terraform State & Enterprise Workflow

## What you will learn

Terraform State is one of the most important Terraform concepts for a Senior/Lead DevOps engineer because it affects collaboration, security, ownership, drift, and production safety.

By the end of this lesson, you should be able to explain why Terraform needs state, how Terraform uses it, why teams move it to a remote backend, why state locking matters, how enterprises divide state between teams, workloads, and environments, and how to safely respond when infrastructure drifts from the Terraform configuration.

---

## Part 1 — Understand Terraform State

1. Why does Terraform need State?

Terraform uses configuration to describe the infrastructure you want, but configuration alone does not tell Terraform everything about the infrastructure it is already managing. Terraform State keeps a record of the resources Terraform knows about and the relationship between those resources and your configuration. During `terraform plan`, Terraform uses the configuration, the state, and the real infrastructure to work out what has changed and what action is required. Without state, Terraform would have a much harder time determining whether an existing resource is the one represented by a particular configuration block.

**Practice**

Create a small Terraform resource and inspect the state after applying it.

```bash
terraform state list
```

Then compare the resources shown by Terraform with the resources you actually created.

**Remember:** State is Terraform's record of the infrastructure it manages.

2. What is inside the State?

A state file contains information Terraform needs to track managed resources, including resource addresses, provider information, resource identifiers, attributes, and relationships between resources. Depending on the resources and configuration, state can also contain values that should be treated as sensitive. This is why a state file should not be treated like an ordinary source-code file or committed casually to a Git repository.

**Practice**

After creating a resource, inspect the state:

```bash
terraform show
```

Look at the information Terraform has recorded.

**Remember:** Terraform State can contain sensitive infrastructure information, so protect it.

3. How does `terraform plan` use State?

When you run `terraform plan`, Terraform does not simply read your `.tf` files and create everything again. It compares your desired configuration with its known state and the current infrastructure returned by the provider. If someone changes a resource outside Terraform, Terraform can detect that difference and may propose a change to bring the infrastructure back toward the configuration. This is the foundation of Terraform's ability to manage infrastructure declaratively.

**Practice**

Create a resource with Terraform, change something about it outside Terraform if the resource safely allows it, and run:

```bash
terraform plan
```

Observe whether Terraform detects the difference.

4. What is Drift?

Drift occurs when the real infrastructure no longer matches what Terraform expects from its configuration and state. A common example is an engineer changing a resource manually through the cloud portal after Terraform created it. During a later plan, Terraform may detect the difference and propose an update. Drift is important in production because unmanaged manual changes make infrastructure harder to understand, audit, reproduce, and troubleshoot.

**Practice**

Make one safe manual change to a lab resource and run:

```bash
terraform plan
```

Ask yourself: "Who changed this, why did they change it, and should Terraform or the manual change be considered the source of truth?"

5. How do you mitigate Drift?

When Terraform detects drift, the first step should not automatically be to run `terraform apply`. First determine what changed, why it changed, and whether the manual change was intentional. Run `terraform plan` to understand the difference, then choose the appropriate response. If the manual change was accidental or should not exist, Terraform can usually reconcile the resource back to the configuration. If the manual change was intentional and should become the new desired state, update the Terraform configuration to represent it and then apply the configuration. If another system legitimately manages a particular attribute, Terraform configuration may need to be designed so that Terraform does not continuously overwrite that attribute.

**Practice**

Use a safe lab resource and practice both scenarios: make an accidental manual change and use Terraform to restore the declared configuration; then make an intentional change, update the Terraform code to represent it, and run `terraform plan` again.

**Remember:** Detect drift, investigate it, then decide whether to reconcile, codify, or deliberately manage the difference.

---

## Part 2 — Move from Local State to Team State

6. What is Local State?

By default, Terraform stores state locally in a `terraform.tfstate` file in the working directory. Local state is convenient for learning and small personal projects because there is no additional backend to configure. The problem appears when several engineers or CI/CD pipelines need to manage the same infrastructure, because each person could otherwise end up with a different copy of state.

**Practice**

Run:

```bash
ls
```

and locate `terraform.tfstate` after applying your lab.

7. Why use Remote State?

Remote State stores the Terraform state in a shared backend rather than on an individual engineer's laptop. This gives the team a common state location that both engineers and CI/CD systems can access. In a real organization, remote state is normally combined with access control, encryption, versioning or recovery capabilities, and locking so that the state becomes a controlled shared resource rather than an unmanaged file.

**Practice**

Identify the remote backend you would use for an Azure Terraform environment and an AWS Terraform environment.

For Azure, a common design is Azure Storage. For AWS, a common design is an S3-based backend with appropriate state-locking support.

8. What is a Terraform Backend?

A backend determines where Terraform stores state and how Terraform accesses that state. The backend is therefore more than "remote storage"; it is the mechanism Terraform uses to persist and retrieve state. In an enterprise setup, backend design should consider security, access control, recovery, collaboration, and locking rather than simply choosing somewhere to upload a file.

**Practice**

Find the backend configuration in a Terraform project and identify where the state is stored, who can access it, how it is protected, and how concurrent access is controlled.

9. Why is State Locking important?

State locking prevents multiple Terraform operations from modifying the same state at the same time when the backend supports locking. Imagine one engineer is running `terraform apply` while another engineer or a CI/CD pipeline starts another apply against the same state. Without appropriate locking, concurrent operations can interfere with each other and potentially produce an inconsistent state or unexpected infrastructure changes. Locking therefore protects the shared state during operations; it does not replace code review or deployment controls.

**Practice**

Look up how the backend you are using implements Terraform state locking and identify what happens when another operation tries to acquire the lock.

**Remember:** Remote State enables collaboration; State Locking protects concurrent operations.

---

## Part 3 — Enterprise State Design

10. Why shouldn't an enterprise use one giant State file?

A small lab can manage many resources from one state file, but a large organization may have hundreds of resources owned by different teams. Putting everything into one state creates a large ownership and access boundary: many people may need access to state that they do not actually need, plans can become larger, and an error affecting one part of the infrastructure can have a wider blast radius. Splitting state allows the organization to create clearer ownership boundaries and reduce unnecessary coupling.

**Practice**

Take a fictional company with Network, Platform, and Application teams. Decide which team should own each state and explain why.

11. Why separate State by Team or Workload?

Different teams should normally have access only to the state they need to manage. For example, the Network team may manage VNet/VPC, subnets, routing, and security infrastructure, while an Application team manages resources belonging to its application. The Application team does not need broad access to the Network team's state just because its application depends on the network. This separation supports least privilege and reduces the blast radius of mistakes.

**Practice**

Consider:

```text
Network Team → Network State
Application Team → Application State
```

Ask: "If the Application team makes a Terraform mistake, how much unrelated infrastructure can that mistake affect?"

12. Why separate State by Environment?

Dev, UAT, and Production should normally have separate state boundaries because they have different risk levels, ownership requirements, credentials, and change controls. A production state should not be casually shared with development workflows. Separating environments also makes it easier to apply different permissions and approval processes while keeping the infrastructure design consistent.

**Practice**

Design state boundaries for Dev, UAT, and Prod. Then decide which identities or pipelines should be allowed to modify each environment.

13. How should State access follow Least Privilege?

Terraform state is an infrastructure asset, so access to it should be granted according to the work someone actually needs to perform. A Network engineer who manages network state does not automatically need access to application state, and a developer should not receive production state access merely because they can view application code. In enterprise environments, backend permissions, cloud IAM/RBAC, CI/CD identities, and environment controls should work together to restrict state access.

**Practice**

Create a simple access model:

```text
Network Team → Network State
Application Team → Application State
Production Pipeline → Production State
```

For each relationship, ask whether read, write, or administrative access is actually required.

**Remember:** Least privilege applies to Terraform State too.

14. How does State design reduce Blast Radius?

Blast radius describes how much infrastructure can potentially be affected by one change or failure. A Terraform state containing an entire enterprise can have a very large blast radius because one plan or apply operates against a huge collection of resources. Smaller, well-designed state boundaries reduce the amount of infrastructure exposed to one Terraform operation and make ownership, review, troubleshooting, and recovery easier.

**Practice**

Compare these designs:

```text
One state → Network + Platform + 50 Applications

Separate states → Network + Platform + Application states
```

Think about what happens when one application needs an infrastructure change.

**Remember:** Smaller state boundaries generally mean smaller operational blast radius.

---

## Part 4 — Safe Terraform Operations

15. Why use a Saved Plan?

In a controlled production workflow, Terraform can generate a plan that is reviewed before the exact plan is applied. This is useful because the team can inspect the proposed infrastructure changes before execution rather than allowing a later apply to recalculate a potentially different plan. A CI/CD pipeline can therefore build the plan, publish it for review or approval, and then apply the approved plan.

**Practice**

Try:

```bash
terraform plan -out=tfplan
terraform show tfplan
```

Understand what Terraform has proposed before applying it.

**Remember:** Plan first, review the change, then apply the approved change.

16. What does `terraform import` solve?

Import allows Terraform to begin managing infrastructure that already exists outside Terraform. Import associates the existing infrastructure with a Terraform resource address, but it does not automatically give you a complete, production-ready Terraform configuration. You still need appropriate configuration and should run a plan to understand what Terraform believes the desired state should be.

**Practice**

Create a small cloud resource manually, then practice importing it into Terraform.

After import, run:

```bash
terraform plan
```

Look for differences between the imported resource and your configuration.

17. Why should Terraform run through CI/CD in Production?

Production infrastructure should not depend on an engineer's laptop as the primary execution environment. A CI/CD pipeline provides a controlled identity, consistent Terraform version and tooling, policy checks, plan review, approvals, audit history, and a repeatable execution path. A typical workflow is code change → validation → plan → review/approval → apply → verification.

**Practice**

Write down the stages you would include in a production Terraform pipeline and identify where you would place approval.

---

## Part 5 — Terraform and Bicep

18. How does Bicep work differently from Terraform?

Terraform and Bicep are both Infrastructure as Code tools, but they manage infrastructure differently. Terraform keeps its own state file to map Terraform resources to real infrastructure and uses that state during planning and changes. Bicep is Azure-specific: a Bicep file is compiled into an ARM template, and Azure Resource Manager performs the deployment using Azure's resource model. Bicep therefore does not maintain a separate Terraform-style state file. The simple mental model is: Terraform uses configuration plus Terraform State and a provider, while Bicep uses Bicep code that is compiled to ARM and deployed through Azure Resource Manager.

This difference also affects operations. With Terraform, state becomes an important team-management concern: where it is stored, who can access it, how it is locked, and how it is divided between workloads and environments. With Bicep, deployment state and resource management are handled through Azure Resource Manager and Azure's access-control model. Bicep is therefore closely integrated with Azure, while Terraform provides a common IaC model across multiple cloud providers.

**Practice**

Explain the deployment path for a simple Azure resource:

```text
Terraform
Terraform code → Terraform State → Azure Provider → Azure

Bicep
Bicep code → ARM Template → Azure Resource Manager → Azure
```

Then explain why Terraform needs its own State while Bicep can rely on Azure Resource Manager's resource model.

---

## Part 6 — Integrated Practice

Build a small Terraform environment and move through the lifecycle:

1. Create a resource with local state.
2. Inspect the state.
3. Make a safe manual change and observe drift.
4. Decide whether the change should be reconciled or codified.
5. Move the state to a remote backend.
6. Identify how locking works.
7. Design separate state boundaries for Network, Platform, and Application.
8. Create separate Dev, UAT, and Prod boundaries.
9. Explain which team or pipeline gets access to each state.
10. Generate a saved plan.
11. Explain how the same workflow would be controlled in production.
12. Explain how the same Azure resource would be managed using Bicep.

The goal is not to create a large amount of infrastructure. The goal is to understand why the state architecture and operational workflow change as the organization grows.

---

**5-Minute Interview Recall**

Before moving on, you should be able to answer these without looking at the notes:

1. Why does Terraform need State?
2. What information does State contain?
3. How does `terraform plan` use State?
4. What is infrastructure drift?
5. How do you safely mitigate drift?
6. Why is Local State unsuitable for a team?
7. What does a Terraform Backend do?
8. Why is State Locking required?
9. Why shouldn't 50 teams share one giant State?
10. Why should Network and Application teams have separate State?
11. Why separate State between Dev, UAT, and Prod?
12. How does least privilege apply to Terraform State?
13. How does State design reduce blast radius?
14. Why use saved plans in Production?
15. What problem does `terraform import` solve?
16. How is Bicep's resource management model different from Terraform State?

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

---

## Part 7 — How Local and Remote State Actually Work Together

A common interview question is: **“How does Terraform synchronize the remote state file with the local state file?”** The safest answer is that with a remote backend, Terraform normally treats the backend as the shared source of state; it is not intended for every engineer to maintain an independent local `terraform.tfstate` copy and synchronize those copies manually.

When Terraform is configured with a remote backend, `terraform init` initializes that backend and Terraform operations read and write state through it. The engineer's working directory contains the configuration and Terraform's local working data, while the shared state remains in the configured backend.

A useful mental model is:

```text
Engineer / CI
     ↓
Terraform configuration
     ↓
Remote Backend
     ↓
Shared Terraform State
     ↓
Cloud Provider
```

If you change from a local backend to a remote backend, Terraform can migrate the existing state during initialization:

```bash
terraform init -migrate-state
```

If the backend configuration itself changed and you want Terraform to reinitialize the backend without automatically migrating the state, a common option is:

```bash
terraform init -reconfigure
```

For troubleshooting or controlled recovery, Terraform can also read the current state from a backend:

```bash
terraform state pull
```

Treat state recovery operations carefully. Commands that write or replace state can cause serious problems if used incorrectly.

Practice by starting with a local state lab, configuring a remote backend, running `terraform init -migrate-state`, and then verifying that the same managed resources are still represented after initialization.

---

## Part 8 — What Happens If Someone Deletes the State File?

First determine **which state was deleted**.

If a local `terraform.tfstate` file was deleted but the project uses a healthy remote backend, the remote state is still the shared state. Reinitializing the backend allows Terraform to use the remote state again.

If the only state copy was local and that file is permanently lost while the real infrastructure still exists, Terraform no longer has its record of which resources it manages. The infrastructure has not automatically disappeared; the management record has disappeared.

This does **not** mean you should immediately run `terraform apply`.

Terraform may now believe resources need to be created because they are absent from state. Some resources may already exist in the cloud, causing conflicts rather than clean creation.

The recovery approach is to restore the state from a protected backup or backend version when possible. If recovery from an existing state copy is impossible, existing resources may need to be imported back into Terraform.

The key distinction is:

```text
State deleted
≠
Infrastructure deleted
```

State is Terraform's management record. Losing it can make safe management much harder, but it does not automatically destroy the cloud resources.

Practice this only in a disposable lab. Never intentionally delete Production state to learn this concept.

---

## Part 9 — State Locking and Concurrent Operations

State locking answers a different question from remote storage.

Remote storage answers:

**“Where is the shared state?”**

Locking answers:

**“Who is currently allowed to perform a state-changing operation against it?”**

Imagine:

```text
Engineer A → terraform apply
Engineer B → terraform apply
```

against the same state at almost the same time.

Without locking or another concurrency-control mechanism, both operations could interfere with each other. A supported backend can acquire a lock while an operation is using the state and make another operation wait or fail rather than allowing conflicting state changes.

The exact locking mechanism depends on the backend and Terraform version. For example, AWS S3 backends support state locking through the backend's supported locking mechanisms, while other backends have their own mechanisms.

Do not confuse state locking with:

```text
Git locking
Code review
Approval
IAM
```

They solve different problems.

A simple mental model is:

```text
Remote Backend
→ shared state location

State Lock
→ protects concurrent state-changing operations

Git Review
→ protects code changes

Approval
→ controls production execution

IAM
→ controls who is allowed to perform actions
```

Practice by running two Terraform operations against the same lab state and observing what happens when the backend lock is already held.

---

## Part 10 — Interview Scenario: The Network Team Must Not See Everything

Imagine an organization has:

```text
Network Team
Platform Team
Application Team
Security Team
```

The organization does not want one giant Terraform state that every team can access.

A better design could be:

```text
Network State
Platform State
Application-A State
Application-B State
Security State
```

The Network team receives access to the network state because it manages network resources. The Application team may need network outputs such as subnet IDs or VPC IDs, but that does not mean it needs unrestricted access to the entire Network team's state.

This is where Terraform state design and least privilege meet.

The principle is:

**Teams should receive access to the state boundaries they need to perform their responsibilities, not access to the entire organization's infrastructure state.**

Practice by designing access for three teams and answering:

```text
Who can read?
Who can modify?
Who can apply?
Who can administer the backend?
```

Then ask what happens if the Application team's Terraform code contains a destructive mistake. A properly separated state boundary limits how much unrelated infrastructure that operation can affect.

---

### Interview Recall

You should now be able to answer:

1. How does Terraform use a remote backend instead of a local state file?
2. What happens during `terraform init -migrate-state`?
3. When would `terraform init -reconfigure` be useful?
4. What does `terraform state pull` do?
5. What happens if a local state file is deleted while remote state still exists?
6. What happens if the only Terraform state is permanently lost?
7. Why should you not immediately run `terraform apply` after losing state?
8. How can existing infrastructure be brought back under Terraform after state loss?
9. What is state locking?
10. How is state locking different from IAM, Git review and Production approval?
11. Why should Network, Platform and Application teams have separate state boundaries?
12. Why should a team not automatically receive access to the whole enterprise Terraform state?


**Cleanup**

If this was only a lab, destroy the resources you created:

```bash
terraform destroy
```

After destruction, verify that the lab resources no longer exist and remove any temporary local files that are no longer needed.
