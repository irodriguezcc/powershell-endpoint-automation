# Enterprise Endpoint & Fleet Automation Toolkit (PowerShell)

Production-tested PowerShell scripts designed for automated endpoint management, silent software remediation, and staged software deployments across large-scale Windows workstation environments (300+ endpoints).

Engineered for seamless integration with enterprise RMM platforms (Action1, Atera), remote management tools (VNC), and hybrid identity environments (Active Directory / Microsoft 365).

---

## 📌 Repository Overview

This repository provides production-grade scripts built with enterprise reliability in mind: structured logging, error handling, local staging validation, and idempotence.

### Modules Included

1. **`01-Office-ClickToRun-Remediation.ps1`**
   * Deep diagnostic and automated repair/reinstall routines for corrupt Microsoft 365 / Office Click-to-Run deployments.
   * Cleans stale registry entries and removes stuck installation lockfiles silently.
2. **`02-Staged-Software-Deployment.ps1`**
   * Robust software staging routine utilizing `Robocopy` with integrated retry limits and network fault tolerance.
   * Validates local package hash integrity prior to executing silent installers.
3. **`03-MultiUser-Cache-And-Compliance-Audit.ps1`**
   * Purges orphaned user profile temporary caches on shared multi-user logistics workstations.
   * Audits local endpoint compliance, active group policies (GPO), and security agent status.

---

## 🛡️ Safety & Deployment Methodology

All scripts in this repository follow strict operational change-management guidelines:
* **Pre-flight System Restore Points:** Critical changes initiate a lightweight local restore checkpoint where supported.
* **Controlled Pilot Groups:** Staging-first validation on test hardware before broad tenant rollout.
* **Exit Codes & Verbose Logging:** Explicit exit codes compatible with RMM execution alerts and audit trails.

---

## 👤 Author
* **Iván Felipe Rodríguez C.** – *IT Support Specialist (L2/L3)*
* **Focus:** Endpoint Administration, Automation & Systems Infrastructure
* **Contact:** [irodriguezcc@outlook.com](mailto:irodriguezcc@outlook.com)
