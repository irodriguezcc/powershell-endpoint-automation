# Enterprise Endpoint & Fleet Automation Toolkit (PowerShell)

Production-tested PowerShell scripts designed for automated endpoint management, silent software remediation, cybersecurity agent rollouts, mass volume licensing, and staged fleet deployments across 300+ Windows workstation environments.

Engineered for unattended execution via enterprise RMM platforms (Action1, Atera), remote management tools (VNC), and hybrid identity environments (Active Directory / Microsoft 365).

---

## 📌 Repository Overview

This repository contains operational automation tools developed and deployed in enterprise logistics and developer environments:

### Modules Included

1. **`01-Office-ClickToRun-DeepScrub.ps1`**
   * Complete administrative purge routine for corrupted Microsoft Office and Click-to-Run installations.
   * Forcefully terminates stuck processes, unregisters update tasks, deletes services (`sc.exe`), and scrubs registry hives across 32-bit and 64-bit paths.

2. **`02-Windows-Debloat-Edge-Copilot-Removal.ps1`**
   * Silent de-bloat routine targeting Microsoft Edge and Windows Copilot on dedicated developer endpoints.
   * Purges AppX packages and enforces persistent Group Policy registry flags against automatic reinstallation.

3. **`03-Staged-Network-Software-Deployment.ps1`**
   * Resilient enterprise software deployment using authenticated SMB and `Robocopy`.
   * Evaluates Robocopy bitmask return codes (`< 8`), stages packages locally to tolerate network drops, and handles automatic cleanup.

4. **`04-Office-Volume-Licensing-Activation.ps1`**
   * Mass unattended volume licensing activation routine for Office deployments across 100+ endpoints.
   * Dynamically locates `OSPP.VBS` across architectures, injects product keys, and audits activation status flags.

5. **`05-TrendMicro-ApexOne-Fleet-Deployment.ps1`**
   * Large-scale fleet rollout (300+ endpoints) for Trend Micro Apex One Security Agent.
   * Features a triple-factor idempotency check (Registry, core services: `ntrtscan`/`OfficeScanAgent`, and file system paths) to eliminate duplicate deployments, paired with authenticated `New-PSDrive` staging and graceful session teardown.

6. **`06-Enterprise-MultiUser-Cache-Purge.ps1`**
   * Deep maintenance routine designed for post-deployment verification and developer workstation hygiene.
   * Cleans Windows Temp, Prefetch, and SoftwareDistribution queues, scrubs browser engines (Chrome, Edge, Firefox, Brave) across all active user profiles, empties the Recycle Bin, and flushes the DNS client resolver cache.

---

## 🛡️ Safety & Deployment Methodology

All scripts in this repository follow strict operational standards:
* **Idempotency:** Pre-flight detection checks prevent duplicate runs, installation collisions, or unintended reconfigurations.
* **Architecture Agnostic:** Dynamic path discovery across standard `Program Files`, `Wow6432Node`, and x86 paths.
* **Network Fault Tolerance:** Local caching/staging prevents corrupted partial installs during transient network drops.
* **Structured Exit Codes:** Clean return codes for accurate monitoring in RMM job summaries and ticketing systems.

---

## 👤 Author
* **Iván Felipe Rodríguez C.** – *IT Support Specialist (L2/L3)*
* **Focus:** Endpoint Administration, Systems Infrastructure & PowerShell Automation
* **Contact:** [irodriguezcc@outlook.com](mailto:irodriguezcc@outlook.com)
