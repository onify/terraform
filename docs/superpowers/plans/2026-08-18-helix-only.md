# Helix-Only Terraform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a non-default Helix-only mode that removes the legacy app and routes root traffic to Helix.

**Architecture:** The root module passes a validated boolean into the existing Helix submodule. Count-gated legacy resources disappear only in that mode, while ingress backends switch declaratively.

**Tech Stack:** Terraform 1.5+, Kubernetes provider, native `terraform test`

**Spec:** `docs/superpowers/specs/2026-08-18-helix-only-design.md`

## Global Constraints

- `helix_only` must default to `false`.
- `helix_only = true` requires `helix = true`.
- Existing legacy and hybrid plans must retain their current routing and resources.
- No customer-specific values belong in the module.

---

### Task 1: Add failing mode and routing tests

**Files:**
- Create: `modules/onify-customer/tests/helix_only.tftest.hcl`

**Interfaces:**
- Tests the public module variables `helix` and `helix_only` and planned Kubernetes resource attributes.

- [ ] **Step 1: Add mocked-provider plan runs** for hybrid default, Helix-only, and invalid legacy-plus-only.
- [ ] **Step 2: Assert hybrid has a legacy StatefulSet/service and root backend port 3000.**
- [ ] **Step 3: Assert Helix-only has no legacy StatefulSet/service, root and `/helix` backends use port 4000, and custom-host rules match.**
- [ ] **Step 4: Run `terraform test` and verify the assertions fail because `helix_only` does not exist.**

### Task 2: Implement the public mode contract

**Files:**
- Modify: `modules/onify-customer/variables.tf`
- Modify: `modules/onify-customer/main.tf`
- Modify: `modules/onify-customer/helix/variables.tf`

**Interfaces:**
- Produces: `variable "helix_only" { type = bool, default = false }` at both module layers.

- [ ] **Step 1: Add the root validation and pass the value to `module.helix`.**
- [ ] **Step 2: Add the submodule variable with the same validation.**
- [ ] **Step 3: Run the focused Terraform test and confirm only resource/routing assertions remain red.**

### Task 3: Gate legacy resources and switch ingress backends

**Files:**
- Modify: `modules/onify-customer/helix/onify-application-hub.tf`
- Modify: `modules/onify-customer/helix/onify-application-helix.tf`

**Interfaces:**
- Legacy StatefulSet/service use `count = var.helix_only ? 0 : 1`.
- Root ingress backend name/port select Helix (`4000`) only when enabled.
- Helix container exports `ONIFY_API_URL_INTERNAL=http://<client>-<instance>-hub-api:8181`.

- [ ] **Step 1: Gate the two legacy app resources and repair counted dependencies.**
- [ ] **Step 2: Switch root backend service/port for both primary and custom host rules.**
- [ ] **Step 3: Keep the `/helix` backend on the Helix service in both hybrid and only modes.**
- [ ] **Step 4: Add the root proxy upstream environment variable to the Helix container.**
- [ ] **Step 5: Run `terraform fmt`, `terraform test`, and `terraform validate`.**

### Task 4: Document the module interface and rollback

**Files:**
- Modify: `modules/onify-customer/README.md`

**Interfaces:**
- Documents the three modes, image prerequisite, and rollback by returning `helix_only` to `false`.

- [ ] **Step 1: Add a concise mode table and example.**
- [ ] **Step 2: State that the selected Helix image must be root/proxy capable and immutable.**
- [ ] **Step 3: Run tests again and inspect `git diff --check`.**
