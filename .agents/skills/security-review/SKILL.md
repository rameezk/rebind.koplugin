---
name: security-review
description: Review a change for security vulnerabilities alone - injection, secrets, auth gaps, unsafe data handling, SSRF/path traversal, crypto misuse, risky dependencies. Read-only; reports findings with severity and evidence, never edits code. Use to security-review a branch or PR, or when asked to "check for vulnerabilities" or "look for leaked secrets".
---

# Security Review

Review the diff between a head commit and a fixed point for **security** and nothing else: how the change could be attacked, not whether it is clean, correct, or faithful to the spec. Stay on security - do not comment on naming, structure, or non-security correctness unless it is the root cause of a security risk.

The review runs off three named references: the **OWASP Top 10 (2021)** as the line-by-line baseline, **CWE** IDs to name each concrete weakness precisely, and **STRIDE** as the lens for tracing threats across the whole change.

This is a strictly read-only pass. It reports; it never edits, writes, formats, stages, or commits, and it runs no command that mutates state - only read-only inspection (`git diff`, `git log`, `git show`, dependency listing, and the like). Fixing a finding is a separate step the user chooses.

## Process

### 1. Pin the fixed point

The fixed point is whatever the user gives - a commit SHA, a branch, a tag, `main`, `HEAD~5`. If they name none, default to the pending change on the current branch, and ask if that is ambiguous. The head is the commit SHA the caller passes, or `HEAD` if they pass none. Resolve both to SHAs once (`git rev-parse`) and use those SHAs everywhere below, never the moving `HEAD`, so the review covers exactly one commit range and says which. Capture the diff three-dot against the merge-base: `git diff <fixed-point>...<head>`. Confirm both refs resolve and the diff is non-empty before going further.

Review the diff so the focus lands on newly introduced risk, but read enough surrounding context in each file to judge whether a change is actually reachable and exploitable - a finding nobody can trigger is noise.

### 2. Inspect against the OWASP Top 10

Work the diff category by category against the **OWASP Top 10 (2021)** - the fixed baseline this review always carries. The full catalog - each category, what to look for, and its CWE IDs - is in [`owasp-top-10.md`](owasp-top-10.md); read it and match every category against the change.

Two rules bind the pass. **Cite precisely**: on each finding name the OWASP category *and* the concrete **CWE ID**. **Redact secrets**: for any hardcoded key, token, password, or credential (OWASP A02), report location and type only and mask the value, all but the last few characters - never print it in full.

A category with no concrete, triggerable instance in the diff is not a finding, and anything a scanner or linter already enforces in CI is out - report what judgement adds.

### 3. Trace the data flow end-to-end - the STRIDE lens

Step back from the line-by-line pass and follow how untrusted input enters the system and where it travels, using **STRIDE** as the lens to catch what a per-file scan misses - a threat that only emerges from how components compose, a taint that crosses file boundaries and is invisible in any single hunk. At each trust boundary the change touches, ask which of these it opens:

- **Spoofing** - can identity be faked? (authentication)
- **Tampering** - can data or code be altered in transit or at rest? (integrity)
- **Repudiation** - can an action be denied for want of a trustworthy log? (non-repudiation)
- **Information disclosure** - can data leak to someone unauthorised? (confidentiality)
- **Denial of service** - can the change be driven to exhaust a resource? (availability)
- **Elevation of privilege** - can a caller gain rights they should not have? (authorization)

Confirm the issues you flagged in step 2 are actually reachable along a real path, and raise any new one this end-to-end view exposes, mapping it back to its OWASP category and CWE.

## Severity

Rate each finding by impact and exploitability:

- **Critical** - trivially exploitable, high impact (exposed live credential, unauthenticated RCE).
- **High** - exploitable with meaningful impact (SQL injection, auth bypass).
- **Medium** - exploitable under specific conditions, or lower impact.
- **Low** - hardening or defence-in-depth; limited direct impact.
- **Info** - worth noting, not a vulnerability on its own.

## Report

Produce a concise report, opening with the reviewed range on its own first line: `Reviewed <fixed-point-sha>...<head-sha>`, both as resolved in step 1. A caller uses it to tell which commit the review covers.

1. **Summary** - a sentence or two on the security posture of the change, and the count of findings by severity.
2. **Findings** - each on its own, most severe first: severity and short title, the **OWASP category and CWE ID**, a `file:line` reference, the concrete attack (not a generic description), the impact if exploited, and a specific remediation. For secrets, location and type only, value redacted.
3. **Dependencies / CVEs** - risky dependencies with package, version, and known CVE, or "None found".
4. **Out of scope / assumptions** - anything you could not verify, and any assumption you made.

Every finding cites a concrete `file:line`. Distinguish confirmed vulnerabilities from potential ones and say which is which. Do not invent findings - if the change is clean, say so plainly.

## Completion

Done when the diff has been matched against every OWASP category in [`owasp-top-10.md`](owasp-top-10.md), the data flow has been traced end-to-end through the STRIDE lens, and the findings are reported with severity, OWASP category, CWE, and `file:line` evidence - or the change is declared clean - under the reviewed range. Then stop: this skill finds vulnerabilities; it does not fix them, and it does not review conventions or spec conformance.
