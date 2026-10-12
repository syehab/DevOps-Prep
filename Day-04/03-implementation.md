# Day 4 — Implementation

This Day uses three files. Read [01-concepts.md](01-concepts.md) first. Answer [02-questions-and-answers.md](02-questions-and-answers.md). Then do this lab.

Day 4 teaches a CI/CD mental model. This lab turns that model into two things you can keep: a delivery-flow diagram, and a real pipeline YAML file. You do not need a paid Azure DevOps organization. A local file is enough. A push to GitHub is optional.

---

## Goal

Draw the path from a developer to a verified release. Then write a GitHub Actions workflow that runs on push, checks out the repository, and runs a trivial test. When you finish, you can point at each box in the flow and say what it does. You can also open a YAML file and name the real keys that make a job run.

The lab stays local unless you choose to push. GitHub hosted runners cost nothing for a public repository and a few private minutes. You create no Azure or AWS resources. Time box: 45 to 75 minutes. Stop when the diagram, the workflow file, and the break-and-fix cycle are complete.

---

## What you need

You need a markdown file or paper for the diagram. You also need Git and Python 3 on your machine. Check them before you start:

```bash
git --version
python3 --version
```

You do not need Azure Pipelines, AWS CodePipeline, or a paid organization. GitHub Actions is the path in this lab because the workflow file is valid on disk even if you never push it. If you already have a small GitHub repository, you may push later. If you do not, keep the files on your laptop and run the test locally.

Create a scratch folder outside this course repository so you do not change course files:

```bash
mkdir -p ~/day-04-cicd-lab
cd ~/day-04-cicd-lab
git init
```

Keep the work in that folder. Do not add a workflow under the DevOps-Prep clone unless you intend that repository to run GitHub Actions.

---

## Steps

1. Create a file named `day-04-delivery-flow.md` in `~/day-04-cicd-lab`. Put the date and one sentence at the top: this diagram is the delivery process, not a product name.

2. Draw the flow in a `text` block. Use this exact path so it matches the lesson:

```text
Developer
    ↓
Git
    ↓
Build
    ↓
Test
    ↓
Artifact
    ↓
Deploy
    ↓
Verify
```

3. Under each box, write one line that states the job of that step. Developer writes a change. Git stores a commit SHA. Build turns source into something you can run. Test is the safety check. Artifact is the finished output. Deploy places that artifact in an environment. Verify checks that the new version is healthy. Keep each line short.

4. Add a second diagram for environments. Do not draw a new build between UAT and Production:

```text
Build once
    ↓
Artifact
    ↓
Dev → UAT → Production
```

Write one sentence under it: the artifact stays the same; configuration, secrets, and network settings change around it. That sentence is the “build once, deploy many times” habit from the lesson.

5. Create a trivial unit test that the pipeline can run. This stands in for the Test box. You are not building a product. You are proving that a failed test can stop the pipeline.

```bash
cat > add.py << 'EOF'
def add(a, b):
    return a + b
EOF

cat > test_add.py << 'EOF'
import unittest
from add import add


class TestAdd(unittest.TestCase):
    def test_add(self):
        self.assertEqual(add(1, 1), 2)


if __name__ == "__main__":
    unittest.main()
EOF
```

6. Run the test on your machine before you write YAML. The pipeline will call the same command. If it fails locally, the job will fail too.

```bash
python3 -m unittest test_add.py -v
```

You should see `test_add` pass. Record the short commit SHA after you commit, because the lesson treats the SHA as the fingerprint of the code the pipeline built:

```bash
git add add.py test_add.py
git commit -m "Add trivial add() and unit test"
git rev-parse --short HEAD
```

7. Create the workflow file. GitHub Actions reads `.github/workflows/` on push. The keys below are real: `on`, `push`, `jobs`, `runs-on`, `steps`, and `uses: actions/checkout@v4`.

```bash
mkdir -p .github/workflows
```

Write `.github/workflows/ci.yml` with this content:

```yaml
name: ci

on: push

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repository
        uses: actions/checkout@v4
      - name: Run unit tests
        run: python3 -m unittest test_add.py -v
```

Read the file once and map it to the flow. `on.push` is Git. `actions/checkout@v4` brings the commit onto the runner. `python3 -m unittest` is Test. This lab has no deploy step on purpose. The file still proves the first half of the path: Developer → Git → Build/checkout → Test.

8. Commit the workflow. A local file is enough to finish the Day. Push only if you have a GitHub remote and you want to see the hosted job.

```bash
git add .github/workflows/ci.yml day-04-delivery-flow.md
git commit -m "Add CI workflow that runs unit tests on push"
```

Optional push, after you add a remote that you own:

```bash
git push -u origin HEAD
```

If you push, open the repository on GitHub. Open the Actions tab. Open the `ci` workflow run. Confirm the job checked out the repository and ran `python3 -m unittest`. If you do not push, skip the hosted run. You already proved the test locally.

Azure DevOps is not required. If you later want the same idea as a file named `azure-pipelines.yml`, you can add it in another Day. Do not start a paid Azure DevOps organization for this lab.

---

## Verify

Read `day-04-delivery-flow.md` out loud as if you are in an interview. Start at Developer and stop at Verify. You should not need a product name to explain the path.

Check these points:

- Every box from Developer through Verify has a one-line job.
- The environment diagram does not rebuild between UAT and Production.
- `.github/workflows/ci.yml` uses real keys: `on`, `push`, `jobs`, `runs-on`, `steps`, and `uses: actions/checkout@v4`.
- `python3 -m unittest test_add.py -v` passes on your machine.
- You can name the short commit SHA of the code you tested.

If the YAML has a key you cannot explain, remove it. A short workflow that you understand is better than a long template that you copied.

---

## Break and fix

Do this on purpose. Open `test_add.py` and change the expected result from `2` to `3`:

```python
self.assertEqual(add(1, 1), 3)
```

Run the same command the job uses:

```bash
python3 -m unittest test_add.py -v
```

The test must fail. That is the Test box doing its job: a bad check stops the path before deploy. If you pushed earlier, commit and push this broken test, then open the Actions run and confirm the job fails.

Then change the assertion back to `2`. Run the test again. Confirm it passes. Commit the fix.

```python
self.assertEqual(add(1, 1), 2)
```

```bash
python3 -m unittest test_add.py -v
```

Write one sentence under your diagram: “Pipeline success is not application health, but a failed test is a real pipeline failure.” Keep that sentence. The green job only proved that this test passed. It did not prove that a user can use a production app.

---

## Clean up

You created no cloud resources. There is no resource group, VPC, or cluster to delete.

If you do not want GitHub Actions on this scratch repository, delete the workflow:

```bash
rm -f .github/workflows/ci.yml
```

Commit that deletion if you already pushed the workflow. Hosted runs leave logs only. The runner virtual machine is gone when the job ends.

Keep `day-04-delivery-flow.md` in your notes. Do not commit secrets. This lab must not contain passwords, keys, or account IDs. If you opened a cloud console out of habit, close it. Create nothing.

---

## Interview story

I describe CI/CD as a delivery process, not as a tool name. A developer commits to Git. The pipeline builds that commit SHA, runs tests, keeps a versioned artifact, deploys that same artifact, and verifies health. I do not rebuild between UAT and Production. If a test fails, the job fails and I do not deploy. If deploy is green and users see HTTP 500, I treat that as an application-health problem, not as proof that the pipeline is wrong.
