# Day 10 — Terraform State & Enterprise Workflow

## What you will learn

Terraform State is one of the most important Terraform concepts for a Senior/Lead DevOps engineer because it affects collaboration, security, ownership, drift, and production safety.

By the end of this lesson, you should be able to explain why Terraform needs state and how Terraform uses it. You should be able to explain why teams move state to a remote backend and why state locking matters. Finally, you should be able to explain how enterprises divide state between teams, workloads, and environments, and how to respond safely when infrastructure drifts from the Terraform configuration.

---

## Part 1 — Understand Terraform State

1. Why does Terraform need State?

Terraform uses configuration to describe the infrastructure you want, but configuration alone does not tell Terraform everything about the infrastructure it is already managing. Terraform State keeps a record of the resources Terraform knows about and the relationship between those resources and your configuration. During `terraform plan`, Terraform uses the configuration, the state, and the real infrastructure to work out what has changed and what action is required. Without state, Terraform would have a much harder time to decide whether an existing resource matches a particular configuration block.

**Practice**

Create a small Terraform resource and inspect the state after applying it.

```bash
terraform state list
```

Then compare the resources shown by Terraform with the resources you actually created.

**Remember:** State is Terraform's record of the infrastructure it manages.

2. What is inside the State?

A state file contains information Terraform needs to track managed resources, including resource addresses, provider information, resource identifiers, attributes, and relationships between resources. Depending on the resources and configuration, state can also contain sensitive values. This is why you should not treat a state file like an ordinary source-code file or commit it casually to a Git repository.

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

Drift occurs when the real infrastructure no longer matches what Terraform expects from its configuration and state. A common example: an engineer changes a resource manually through the cloud portal after Terraform created it. During a later plan, Terraform may detect the difference and propose an update. Drift is important in production because unmanaged manual changes make infrastructure harder to understand, audit, reproduce, and troubleshoot.

**Practice**

Make one safe manual change to a lab resource and run:

```bash
terraform plan
```

Ask yourself: "Who changed this, why did they change it, and which is the source of truth: Terraform or the manual change?"

5. How do you mitigate Drift?

When Terraform detects drift, the first step should not automatically be to run `terraform apply`. First determine what changed, why it changed, and whether the manual change was intentional. Run `terraform plan` to understand the difference, then choose the appropriate response. If the manual change was accidental or should not exist, Terraform can usually reconcile the resource back to the configuration. If the manual change was intentional and should become the new desired state, update the Terraform configuration to represent it and then apply the configuration. If another system legitimately manages a particular attribute, design the Terraform configuration so that Terraform does not continuously overwrite that attribute.

**Practice**

Use a safe lab resource and practice both scenarios. First, make an accidental manual change and use Terraform to restore the declared configuration. Then make an intentional change, update the Terraform code to represent it, and run `terraform plan` again.

**Remember:** Detect drift, investigate it, then decide whether to reconcile, codify, or deliberately manage the difference.

---

## Part 2 — Move from Local State to Team State

6. What is Local State?

By default, Terraform stores state locally in a `terraform.tfstate` file in the working directory. Local state is convenient for learning and small personal projects because there is no additional backend to configure. The problem appears when several engineers or CI/CD pipelines manage the same infrastructure. Each person could otherwise end up with a different copy of state.

**Practice**

Run:

```bash
ls
```

and locate `terraform.tfstate` after applying your lab.

7. Why use Remote State?

Remote State stores the Terraform state in a shared backend rather than on an individual engineer's laptop. This gives the team a common state location that both engineers and CI/CD systems can access. In a real organization, teams normally combine remote state with access control, encryption, versioning or recovery capabilities, and locking. The state then becomes a controlled shared resource rather than an unmanaged file.

**Practice**

Identify the remote backend you would use for an Azure Terraform environment and an AWS Terraform environment.

For Azure, a common design is Azure Storage. For AWS, a common design is an S3-based backend with appropriate state-locking support.

8. What is a Terraform Backend?

A backend determines where Terraform stores state and how Terraform accesses that state. The backend is therefore more than "remote storage"; it is the mechanism Terraform uses to persist and retrieve state. In an enterprise setup, backend design should consider security, access control, recovery, collaboration, and locking rather than simply choosing somewhere to upload a file.

**Practice**

Find the backend configuration in a Terraform project. Identify where the state lives, who can access it, how it is protected, and how the backend controls concurrent access.

9. Why is State Locking important?

State locking prevents multiple Terraform operations from modifying the same state at the same time when the backend supports locking. Imagine one engineer is running `terraform apply` while another engineer or a CI/CD pipeline starts another apply against the same state. Without appropriate locking, concurrent operations can interfere with each other and potentially produce an inconsistent state or unexpected infrastructure changes. Locking therefore protects the shared state during operations; it does not replace code review or deployment controls.

**Practice**

Look up how the backend you are using implements Terraform state locking and identify what happens when another operation tries to acquire the lock.

**Remember:** Remote State enables collaboration; State Locking protects concurrent operations.

---

## Part 3 — Enterprise State Design

10. Why shouldn't an enterprise use one giant State file?

A small lab can manage many resources from one state file, but a large organization may have hundreds of resources owned by different teams. One state for everything creates a large ownership and access boundary. Many people get access to state that they do not actually need, plans become larger, and an error in one part of the infrastructure can have a wider blast radius. When you split state, the organization gets clearer ownership boundaries and less unnecessary coupling.

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

Terraform state is an infrastructure asset, so access to it should be granted according to the work someone actually needs to perform. A Network engineer who manages network state does not automatically need access to application state. A developer should not receive production state access merely because they can view application code. In enterprise environments, backend permissions, cloud IAM/RBAC, CI/CD identities, and environment controls should work together to restrict state access.

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

Blast radius describes how much infrastructure one change or failure can potentially affect. A Terraform state that contains an entire enterprise has a very large blast radius, because one plan or apply operates against a huge collection of resources. Smaller, well-designed state boundaries reduce the amount of infrastructure exposed to one Terraform operation and make ownership, review, troubleshooting, and recovery easier.

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

In a controlled production workflow, Terraform generates a plan, the team reviews it, and Terraform applies that exact plan. This is useful because the team can inspect the proposed infrastructure changes before execution. A later apply then cannot recalculate a potentially different plan. A CI/CD pipeline can therefore build the plan, publish it for review or approval, and then apply the approved plan.

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

Terraform and Bicep are both Infrastructure as Code tools, but they manage infrastructure differently. Terraform keeps its own state file to map Terraform resources to real infrastructure and uses that state during planning and changes. Bicep is Azure-specific: the tooling compiles a Bicep file into an ARM template, and Azure Resource Manager runs the deployment with Azure's resource model. Bicep therefore does not keep a separate Terraform-style state file. The simple mental model is: Terraform uses configuration plus Terraform State and a provider. Bicep code compiles to ARM and deploys through Azure Resource Manager.

This difference also affects operations. With Terraform, state becomes an important team-management concern: where it is stored, who can access it, how it is locked, and how it is divided between workloads and environments. With Bicep, Azure Resource Manager and Azure's access-control model handle deployment state and resource management. Bicep is therefore closely integrated with Azure, while Terraform provides a common IaC model across multiple cloud providers.

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

**Cleanup**

If this was only a lab, destroy the resources you created:

```bash
terraform destroy
```

After destruction, verify that the lab resources no longer exist and remove any temporary local files that are no longer needed.

## Answers to practice

### 1. Inspect state after apply with `terraform state list`

<details>
<summary>Answer</summary>

Create a small resource, run `terraform apply`, then run `terraform state list`. You should see addresses such as `aws_s3_bucket.app`. Compare that list with the real cloud resource you created.

They should match for this project. State is Terraform’s record of the infrastructure it manages. It is not a full inventory of the cloud account.

</details>

### 2. What you see in state with `terraform show`

<details>
<summary>Answer</summary>

After apply, run `terraform show`. Terraform prints resource addresses, IDs, attributes, and provider information it recorded. You may also see values that are sensitive, depending on the resource.

Protect this output. Do not commit `terraform.tfstate` or paste `terraform show` into a ticket. State can contain secrets. Treat it as infrastructure data, not as ordinary source code.

</details>

### 3. How `terraform plan` uses state after an outside change

<details>
<summary>Answer</summary>

Create a resource with Terraform. Change one safe attribute outside Terraform. Run `terraform plan`. Terraform does not only reread `.tf` files and create everything again.

It compares configuration, state, and current infrastructure from the provider. You should see a proposed update that moves the resource back toward the code, or a note that an attribute drifted. That comparison is how declarative management works.

</details>

### 4. What drift is, and who is the source of truth

<details>
<summary>Answer</summary>

Drift means real infrastructure no longer matches what Terraform expects from configuration and state. A portal change after apply is the usual lab example. Run `terraform plan` and you should see the difference.

Ask who changed it and why. If the code is the source of truth, the manual change is the error. If the manual change was a required exception, the code is stale. Do not apply until you answer that.

</details>

### 5. Mitigate drift: restore accidental change, or codify an intentional one

<details>
<summary>Answer</summary>

Do not start with `terraform apply`. Run `terraform plan`, learn what changed, then choose.

1. Accidental change: keep the code. Apply so Terraform restores the declared configuration.
2. Intentional change: update the Terraform code to match, then plan. The plan should shrink toward no changes.
3. If another system owns an attribute, design the resource so Terraform does not keep overwriting it.

Detect, investigate, then reconcile, codify, or deliberately live with the difference.

</details>

### 6. Find local state with `ls`

<details>
<summary>Answer</summary>

After apply, run `ls` in the working directory. You should see `terraform.tfstate`. That file is local state. It is convenient for a personal lab.

It is a problem for a team, because each laptop can hold a different copy. Do not treat that file as shareable source. Do not commit it.

</details>

### 7. Remote backends you would use on Azure and AWS

<details>
<summary>Answer</summary>

For Azure Terraform, a common remote backend is Azure Storage. For AWS Terraform, a common design is an S3-based backend with state-locking support.

Remote state gives engineers and CI/CD one shared location. Combine it with access control, encryption, versioning or recovery, and locking. The state then becomes a controlled shared resource, not a laptop file.

</details>

### 8. What a backend configuration must answer

<details>
<summary>Answer</summary>

Find the `backend` block in the Terraform project. Read where state lives (storage account or S3 bucket), who can access it, how it is encrypted, and how concurrent access is locked.

A backend is how Terraform stores and retrieves state, not only “a place to upload a file.” Enterprise design must cover security, recovery, collaboration, and locking together.

</details>

### 9. How state locking protects concurrent operations

<details>
<summary>Answer</summary>

Look up locking for your backend. Azure Storage and S3-based backends take a lock when an operation such as `terraform apply` runs. A second apply against the same state should wait or fail with a lock error until the first operation ends.

Locking stops two applies from corrupting state. It does not replace code review or approval. Remote state enables collaboration. Locking protects the shared file during operations.

</details>

### 10. Who owns state for Network, Platform, and Application teams

<details>
<summary>Answer</summary>

Give the Network team network state (VPC/VNet, subnets, routing, network security). Give the Platform team shared platform state (cluster, shared logging, common services). Give each Application team only its application state.

Do not put all three in one giant state file. Ownership, access, and blast radius stay clear when each team’s apply can only touch the state it owns.

</details>

### 11. Blast radius if the Application team makes a Terraform mistake

<details>
<summary>Answer</summary>

If Application state is separate, a mistake should affect that application’s resources, not the whole network. The Application team does not need write access to Network state just because the app uses the network.

If everything shares one state, one bad apply can plan against network, platform, and many apps. Separate state keeps least privilege and a smaller blast radius.

</details>

### 12. Separate state for Dev, UAT, and Prod, and who may change each

<details>
<summary>Answer</summary>

Give Dev, UAT, and Prod separate state. They have different risk, credentials, and change control. A Dev pipeline identity should not write Prod state.

Allow Dev engineers and the Dev pipeline to change Dev state. Restrict UAT to the UAT pipeline and a smaller owner set. Allow only the production pipeline, with approval, to change Prod state. Do not share Prod state with casual Dev workflows.

</details>

### 13. Least-privilege access to Network, Application, and production state

<details>
<summary>Answer</summary>

Network Team → Network State: write for network engineers and the network pipeline; no automatic access to application state. Application Team → Application State: write for that app’s pipeline; read network outputs if needed, not admin on network state.

Production Pipeline → Production State: write during approved apply only. Developers who can read app code do not automatically get Prod state. Ask for each relationship whether read, write, or admin is actually required.

</details>

### 14. One giant state versus separate Network, Platform, and Application states

<details>
<summary>Answer</summary>

One state that holds network, platform, and 50 applications has a huge blast radius. One plan operates on everything. Many people get access they do not need. An application change can fail in the middle of a giant apply.

Separate states mean an application change touches only application state. Network and other apps stay outside that operation. Smaller state boundaries generally mean smaller operational blast radius.

</details>

### 15. Saved plan with `terraform plan -out=tfplan`

<details>
<summary>Answer</summary>

Run `terraform plan -out=tfplan`, then `terraform show tfplan`. Read the proposed creates, updates, and destroys before any apply. In production, apply that file so Terraform cannot calculate a different plan later.

A pipeline can build the plan, publish it for review, and apply only the approved file. Plan first. Review the change. Then apply the approved change.

</details>

### 16. What `terraform import` solves, and what you must do after it

<details>
<summary>Answer</summary>

Create a small cloud resource by hand, write a matching resource block, and import it so Terraform associates that object with a resource address. Import starts management of existing infrastructure. It does not write a complete production-ready configuration for you.

After import, run `terraform plan`. Look for differences between the imported object and your configuration. Fix the code until the plan is understood. Then apply only if you intend those remaining changes.

</details>

### 17. Stages of a production Terraform pipeline, and where approval sits

<details>
<summary>Answer</summary>

Use: code change → validate → `terraform plan -out=tfplan` → review and approval → `terraform apply tfplan` → verify. Put approval after the saved plan and before apply.

Production should not run from a laptop. The pipeline supplies a controlled identity, a pinned Terraform version, policy checks, audit history, and a repeatable path.

</details>

### 18. Why Terraform needs its own state while Bicep uses Azure Resource Manager

<details>
<summary>Answer</summary>

Terraform path: Terraform code → Terraform state → provider → cloud. Bicep path: Bicep code → ARM template → Azure Resource Manager → Azure. Terraform needs state to map resource addresses to real objects across providers.

Bicep is Azure-specific. ARM already stores Azure resource and deployment data, so Bicep does not keep a Terraform-style state file. Terraform operations then center on backend, lock, and state split. Bicep operations center on ARM and Azure access control.

</details>

### 19. Integrated Practice — Create a resource with local state

<details>
<summary>Answer</summary>

Write a small resource, run `terraform init`, then `terraform apply`. Confirm `terraform.tfstate` exists in the working directory. Confirm the cloud resource exists.

You now have local state. That is enough for a lab. It is not enough for a team.

</details>

### 20. Integrated Practice — Inspect the state

<details>
<summary>Answer</summary>

Run `terraform state list` and `terraform show`. `state list` should show the resource address. `show` should show IDs and attributes.

Do not share the file. Confirm that Terraform’s record matches the resource you created, and that nothing else in the account appears in this state.

</details>

### 21. Integrated Practice — Make a safe manual change and observe drift

<details>
<summary>Answer</summary>

Change one safe attribute in the portal. Run `terraform plan`. Terraform should report an update that restores the coded value, or otherwise show the drifted attribute.

You have observed drift: the cloud moved, the code did not. Record what changed before you decide the next step.

</details>

### 22. Integrated Practice — Reconcile or codify the manual change

<details>
<summary>Answer</summary>

If the portal change was accidental, apply the existing code and restore the resource. If it was intentional, edit the Terraform configuration to match, then run `terraform plan` until the remaining actions are the ones you want.

Do not skip the investigation. The source of truth is a decision, not an automatic apply.

</details>

### 23. Integrated Practice — Move state to a remote backend

<details>
<summary>Answer</summary>

Configure a remote backend: Azure Storage for Azure, or S3 with locking for AWS. Run `terraform init` so Terraform migrates state to that backend. Confirm local `terraform.tfstate` is no longer the live copy the team will use.

Engineers and CI/CD now share one state location. Protect it with encryption and tight identity access.

</details>

### 24. Integrated Practice — Identify how locking works

<details>
<summary>Answer</summary>

Confirm the backend’s lock mechanism. During apply, the backend holds a lock on that state. A second plan or apply on the same state should not run at the same time.

If someone starts a second apply, they should see a lock error or wait. Unlock only through the supported backend process after a true interrupted run, not as a habit.

</details>

### 25. Integrated Practice — Separate Network, Platform, and Application state

<details>
<summary>Answer</summary>

Design three states: Network, Platform, Application. Network owns connectivity. Platform owns shared runtime. Application owns app resources.

An application apply then cannot destroy a subnet in the same operation. Teams get least privilege. Troubleshooting has a smaller scope.

</details>

### 26. Integrated Practice — Separate Dev, UAT, and Prod boundaries

<details>
<summary>Answer</summary>

Give each environment its own state, credentials, and pipeline. Dev state must not be the Prod file. UAT sits in the middle with tighter control than Dev.

You can still reuse the same module. State boundaries change with risk. The module does not.

</details>

### 27. Integrated Practice — Which team or pipeline gets access to each state

<details>
<summary>Answer</summary>

Network pipeline writes network state. Platform pipeline writes platform state. Each application pipeline writes only that application’s state in that environment.

Prod state accepts writes from the production pipeline after approval. Developers get Dev application state, not Prod admin. Read access to outputs can be wider than write access to state.

</details>

### 28. Integrated Practice — Generate a saved plan

<details>
<summary>Answer</summary>

Run `terraform plan -out=tfplan`. Run `terraform show tfplan` and read every action. Keep that file as the artifact you would approve.

Do not run a fresh `terraform apply` with no arguments if the goal is to apply the reviewed plan. Apply `tfplan` so the executed change matches the review.

</details>

### 29. Integrated Practice — How production would control the same workflow

<details>
<summary>Answer</summary>

In production, Git review starts the change. CI validates and writes a saved plan. Approvers read that plan. Only then does the production identity apply the plan and verify the result.

No laptop is the execution environment. Version pins, policy checks, locking, and audit logs all sit on that path. That is the enterprise workflow this lesson aims at.

</details>

### 30. Integrated Practice — How Bicep would manage the same Azure resource

<details>
<summary>Answer</summary>

Describe the resource in Bicep, pass values with `.bicepparam`, preview with `az deployment group what-if`, then deploy with `az deployment group create`. Azure Resource Manager records the deployment. You do not operate a Terraform state file.

Access control still matters, but it is Azure RBAC and deployment scopes, not a Terraform backend. Same resource goal. Different operational model.

</details>

### 31. Interview Recall — Why does Terraform need State?

<details>
<summary>Answer</summary>

Configuration describes what you want. State records what Terraform already manages and maps each resource block to a real object. During `terraform plan`, Terraform uses configuration, state, and the real infrastructure to decide the action.

Without state, Terraform cannot reliably tell whether an existing resource belongs to a given block. State is required for declarative management.

</details>

### 32. Interview Recall — What information does State contain?

<details>
<summary>Answer</summary>

State contains resource addresses, provider information, resource IDs, attributes, and relationships. It can also contain sensitive values.

That is why you protect it and do not commit it as ordinary source. It is Terraform’s working record, not a friendly export for Git.

</details>

### 33. Interview Recall — How does `terraform plan` use State?

<details>
<summary>Answer</summary>

`terraform plan` compares desired configuration with known state and with current infrastructure from the provider. It then proposes create, update, replace, or destroy.

If someone changed a resource outside Terraform, plan can detect that difference. Plan does not blindly recreate everything from `.tf` files.

</details>

### 34. Interview Recall — What is infrastructure drift?

<details>
<summary>Answer</summary>

Drift is when real infrastructure no longer matches configuration and state. A common cause is a manual portal change after Terraform created the resource.

Drift makes production harder to audit, reproduce, and troubleshoot, because the live system is no longer the coded system.

</details>

### 35. Interview Recall — How do you safely mitigate drift?

<details>
<summary>Answer</summary>

Run `terraform plan` first. Learn what changed and why. Then choose: apply to restore the code, update the code to match an intentional change, or exclude an attribute another system owns.

Do not make apply the first reflex. Detect, investigate, then reconcile or codify.

</details>

### 36. Interview Recall — Why is Local State unsuitable for a team?

<details>
<summary>Answer</summary>

Local state is `terraform.tfstate` on one disk. Each engineer or pipeline can hold a different copy. Two applies can then conflict and corrupt the record.

Teams need one shared remote state. Local state is for learning and small personal projects.

</details>

### 37. Interview Recall — What does a Terraform Backend do?

<details>
<summary>Answer</summary>

A backend decides where Terraform stores state and how it reads and writes that state. It is the persistence mechanism, not only a storage account name.

Enterprise backends must provide access control, encryption, recovery, collaboration, and locking.

</details>

### 38. Interview Recall — Why is State Locking required?

<details>
<summary>Answer</summary>

Locking stops two Terraform operations from changing the same state at once. One apply while another apply runs can produce inconsistent state or unexpected infrastructure.

Locking protects concurrent operations. It does not replace review, IAM, or approval gates.

</details>

### 39. Interview Recall — Why shouldn’t 50 teams share one giant State?

<details>
<summary>Answer</summary>

One giant state gives a huge ownership and access boundary. Plans become large. An error in one application can sit in an apply that also touches unrelated infrastructure.

Split state so each team owns what it manages. You reduce coupling and blast radius.

</details>

### 40. Interview Recall — Why should Network and Application teams have separate State?

<details>
<summary>Answer</summary>

The Network team manages VPC/VNet, subnets, routing, and network security. The Application team manages application resources. The app team should not get broad write access to network state.

Separate state enforces least privilege. An application mistake then cannot rewrite the network in the same operation.

</details>

### 41. Interview Recall — Why separate State between Dev, UAT, and Prod?

<details>
<summary>Answer</summary>

Those environments have different risk, credentials, and change control. Prod state must not be the Dev file. Permissions and approvals can then differ while the module design stays the same.

Separating environments keeps a Dev experiment from writing production state.

</details>

### 42. Interview Recall — How does least privilege apply to Terraform State?

<details>
<summary>Answer</summary>

Grant state access only for the work someone must do. A network engineer does not automatically need application state. A developer does not get Prod state because they can read app code.

Backend permissions, cloud IAM/RBAC, CI/CD identities, and environment gates should agree. Terraform state is an infrastructure asset.

</details>

### 43. Interview Recall — How does State design reduce blast radius?

<details>
<summary>Answer</summary>

Blast radius is how much infrastructure one change or failure can affect. A state that contains the whole enterprise makes every plan and apply huge.

Smaller state boundaries mean one operation touches fewer resources. Ownership, review, troubleshooting, and recovery all get easier.

</details>

### 44. Interview Recall — Why use saved plans in Production?

<details>
<summary>Answer</summary>

A saved plan lets the team review the exact change, then apply that file. A later apply does not recalculate a different plan. Pipelines can publish `tfplan` for approval and apply only after sign-off.

That is plan, review, apply the approved change. It is the controlled production workflow.

</details>

### 45. Interview Recall — What problem does `terraform import` solve?

<details>
<summary>Answer</summary>

`terraform import` associates existing infrastructure with a Terraform resource address so Terraform can start managing it. It does not generate a finished production configuration by itself.

You still write the resource block and run `terraform plan` to see remaining differences. Import is the join between old portal resources and new code.

</details>

### 46. Interview Recall — How is Bicep’s model different from Terraform State?

<details>
<summary>Answer</summary>

Terraform keeps its own state file and uses a provider. Bicep compiles to ARM, and Azure Resource Manager deploys and tracks Azure resources. Bicep does not keep a Terraform-style state file.

Terraform therefore needs remote state, locking, and state splits. Bicep leans on ARM and Azure access control. Both are IaC. Their operational concerns differ.

</details>
