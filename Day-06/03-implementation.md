# Day 6 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 6 turns the CI/CD path into an Azure Pipelines YAML file. You write stages named Build, Test, and Publish. You also run a tiny Python test on your machine. You do not need an Azure DevOps organization. The YAML file plus the local test is enough.

---

## Goal

Write a real `azure-pipelines.yml` that describes three stages: Build, Test, and Publish. Build copies a small Python file into a `dist` folder. Test runs `python3 -m unittest`. Publish names that `dist` folder as a pipeline artifact.

When you finish, you can open the YAML and point at `trigger`, `pool`, `stages`, `stage`, `jobs`, `job`, `steps`, `script`, and `publish`. You can also fail the local test on purpose and watch the same command stop the path before any deploy.

This lab stays on your machine. You create no Azure resources and you do not start a paid organization. Time box: 45 to 75 minutes. Stop when the YAML, the passing test, and the break-and-fix cycle are complete.

---

## What you need

You need Git and Python 3. Check both before you start:

```bash
git --version
python3 --version
```

You do not need Maven, Java, an Azure DevOps org, or a hosted agent. Azure Pipelines reads `azure-pipelines.yml` when a repository is connected. A file on disk is still valid YAML even if Azure never runs it. This lab uses Python because you can run the Test stage locally with `python3 -m unittest`.

Create a scratch folder outside this course repository. Do not add pipeline files under the DevOps-Prep clone unless you intend that repository to run Azure Pipelines.

```bash
LAB_DIR="/tmp/day-06-pipeline-lab-$$"
mkdir -p "$LAB_DIR"
cd "$LAB_DIR"
git init -b main
```

Confirm you are not in the course repository:

```bash
pwd
git rev-parse --show-toplevel
```

Keep all lab files in that folder. Do not put passwords, keys, or organization names in the files. Cost stays at ₹0.

---

## Steps

1. Create a notes file named `day-06-pipeline-lab.md` in `$LAB_DIR`. Put the date at the top. Write one sentence: this lab describes an application pipeline, not an IaC plan-review-approve-apply pipeline. Stay in this folder for the rest of the lab.

2. Draw the path the YAML will describe. Use this exact flow so it matches the lesson:

```text
main
 ↓
Build
 ↓
Test
 ↓
Artifact
```

Under each box, write one line. `main` is the Git branch that starts the run. Build turns source into a known file. Test is the safety check. Artifact is the hand-off that later deploy stages would consume. This lab stops at the artifact. It does not deploy to DEV, UAT, or PROD.

3. Create a tiny Python application. This stands in for the JAR in the lesson. You are not building a product. You are creating one file that Build can copy and Test can import.

```bash
cat > app.py << 'EOF'
def greeting():
    return "ok"


if __name__ == "__main__":
    print(greeting())
EOF
```

4. Create a unit test that the Test stage will run. The pipeline will call the same command you run locally. If the test fails on your machine, the Test stage would fail on an agent too.

```bash
cat > test_app.py << 'EOF'
import unittest
from app import greeting


class TestGreeting(unittest.TestCase):
    def test_greeting(self):
        self.assertEqual(greeting(), "ok")


if __name__ == "__main__":
    unittest.main()
EOF
```

5. Run the test on your machine before you write YAML.

```bash
python3 -m unittest test_app.py -v
```

You should see `test_greeting` pass. Record the short commit SHA after you commit, because the lesson treats the SHA as the fingerprint of the code the pipeline built:

```bash
git add app.py test_app.py
git commit -m "Add tiny greeting app and unit test"
git rev-parse --short HEAD
```

Paste that short SHA into your notes.

6. Practice the Build stage locally. Azure Pipelines would run this on a clean agent. You run the same commands here so `dist/` exists on disk. `python3 -m compileall` checks that the file parses. It does not create a JAR. The copy into `dist/` is the known output.

```bash
python3 -m compileall app.py
mkdir -p dist
cp app.py dist/app.py
ls dist
```

You should see `dist/app.py`. Write one sentence in the notes: later stages would use this file. They would not compile the source again.

7. Create `azure-pipelines.yml` in the lab folder. The keys below are real Azure Pipelines keys: `trigger`, `pool`, `stages`, `stage`, `jobs`, `job`, `steps`, `script`, and `publish`. `vmImage` is the hosted-agent image name under `pool`. `dependsOn` is the same key the lesson uses to order stages. `displayName` labels a step in the run log. `artifact` is the name of the published output.

```yaml
trigger:
- main

pool:
  vmImage: ubuntu-latest

stages:
- stage: Build
  jobs:
  - job: BuildApp
    steps:
    - script: |
        python3 -m compileall app.py
        mkdir -p dist
        cp app.py dist/app.py
      displayName: Build application

- stage: Test
  dependsOn: Build
  jobs:
  - job: TestApp
    steps:
    - script: python3 -m unittest test_app.py -v
      displayName: Run tests

- stage: Publish
  dependsOn: Test
  jobs:
  - job: PublishArtifact
    steps:
    - script: |
        mkdir -p dist
        cp app.py dist/app.py
      displayName: Stage artifact files
    - publish: dist
      artifact: app
```

Read the file once and map it to the flow. `trigger` is the Git event. `pool` is the agent that runs the job. Each `stage` is a major stop. Each `job` groups work on that agent. Each `script` step is one action. The `publish` step names `dist` as artifact `app`. That is the hand-off. This lab has no DEV, UAT, or PROD stage on purpose.

Each Azure Pipelines job starts from a fresh checkout of the repository. That is why the Publish stage copies `app.py` into `dist` again before `publish`. You do not need `DownloadPipelineArtifact` for this small lab. You also do not run this YAML on Azure. The local `unittest` command is the proof that Test works.

8. Commit the YAML and the notes. A local file is enough to finish the Day. Do not create an Azure DevOps organization for this lab.

```bash
git add azure-pipelines.yml day-06-pipeline-lab.md
git commit -m "Add Azure Pipelines YAML with Build Test Publish stages"
```

Optional: if you already have an Azure DevOps project that you own, you may connect this folder later. Skip that today. The YAML on disk plus the local test completes the exercise.

---

## Verify

Read `azure-pipelines.yml` out loud as if you are in an interview. Start at `trigger` and stop at `publish`. You should not need the Azure portal to explain the path.

Check these points:

- The file uses real keys: `trigger`, `pool`, `stages`, `stage`, `jobs`, `job`, `steps`, `script`, and `publish`.
- There are three stages named Build, Test, and Publish. Test depends on Build. Publish depends on Test.
- `python3 -m unittest test_app.py -v` passes on your machine.
- `dist/app.py` exists after the local build commands.
- You can name the short commit SHA of the code you tested.
- The notes say this is an application pipeline. It is not an IaC plan-review-approve-apply pipeline.

If the YAML has a key you cannot explain, remove it. A short pipeline that you understand is better than a long template that you copied.

---

## Break and fix

Do this on purpose. Open `test_app.py` and change the expected result from `"ok"` to `"fail"`:

```python
self.assertEqual(greeting(), "fail")
```

Run the same command the Test stage uses:

```bash
python3 -m unittest test_app.py -v
```

The test must fail. That is the Test stage doing its job. A failed check stops the path before Publish and before any later deploy. Do not edit `azure-pipelines.yml` to hide the failure.

Then change the assertion back to `"ok"`. Run the test again. Confirm it passes.

```python
self.assertEqual(greeting(), "ok")
```

```bash
python3 -m unittest test_app.py -v
```

Write one sentence under your diagram: “A failed test is a real pipeline failure. A green Test stage is not proof that a production application is healthy.” Keep that sentence. The local pass only proved this unit test. It did not deploy anything.

---

## Clean up

You created no cloud resources. There is no Azure DevOps organization to delete, no resource group, and no hosted-agent bill from this lab.

Remove the scratch folder when you are done. The course repository must stay unchanged.

```bash
cd /
rm -rf "$LAB_DIR"
```

If you kept `day-06-pipeline-lab.md` as notes outside `/tmp`, strip any pasted SHA that you do not want to keep. Do not commit secrets. This lab must not contain passwords, keys, or account IDs. If you opened the Azure portal out of habit, close it. Create nothing.

---

## Interview story

I describe an Azure DevOps application pipeline as stages, not as a YAML trick. A trigger on `main` starts the run. Build creates a known file. Test runs `python3 -m unittest` and must fail the job when a check fails. Publish hands that same file to later stages as a pipeline artifact. I do not rebuild for Production. This path ships software. An IaC pipeline uses the same stages and approvals, but it promotes a reviewed plan, not a JAR.
