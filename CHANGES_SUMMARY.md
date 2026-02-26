# Platform Automation Toolkit - Support Boundary Clarification Changes

**Branch:** `clarify-tanzu-platform-support-boundaries` (from v5.4)  
**Date:** February 26, 2026  
**Context:** Clarifying that Platform Automation Toolkit is supported when used with Concourse for VMware Tanzu on the Tanzu Platform

## Business Context

NatWest is using Platform Automation Toolkit with OpenShift (off-platform). The current documentation suggests it can work with any "CI/CD platform," which creates ambiguity about what VMware supports. These changes clarify that:

- **Supported:** Platform Automation Toolkit with Concourse for VMware Tanzu on the Tanzu Platform
- **Not Supported:** Off-platform use with other CI/CD systems (e.g., OpenShift, Jenkins, GitLab CI)

## Changes Made

### 1. `docs/index.html.md.erb` (Main Overview Page)

**Line 26-28:** Changed CI system description
```diff
- in a containerized Continuous Integration (CI) system.<br>
+ in Concourse for VMware Tanzu, the supported CI/CD component of the Tanzu Platform.<br>
```

**Impact:** Clarifies from the start that the supported CI/CD system is Concourse for VMware Tanzu, not any generic CI system.

---

**Line 46:** Changed support statement
```diff
- * Can be used with a documented and supported deployment of Concourse CI.
+ * Is supported when used with Concourse for VMware Tanzu on the Tanzu Platform.
```

**Impact:** Makes explicit that support is tied to Concourse for VMware Tanzu on the Tanzu Platform.

---

### 2. `docs/pipelines/resources.html.md.erb` (Pipeline Reference)

**Line 5:** Replaced permissive language with support boundary
```diff
- These Concourse pipelines are examples on how to use the tasks. If you use a different CI/CD platform, you can use these Concourse files as examples of the inputs, outputs, and arguments used in each step in the workflow.
+ These Concourse pipelines are examples of how to use the tasks with Concourse for VMware Tanzu. Platform Automation Toolkit is supported when used with Concourse for VMware Tanzu on the Tanzu Platform. While the task definitions may be adaptable to other systems, only deployments using Concourse for VMware Tanzu are within the scope of VMware support.
```

**Impact:** 
- Removes suggestion that other CI/CD platforms are viable alternatives
- Explicitly states support scope
- Acknowledges technical adaptability while clarifying support boundaries

---

### 3. `docs/pipelines/multiple-products.html.md.erb` (Multi-Product Pipeline)

**Line 5:** Same change as resources.html.md.erb
```diff
- These Concourse pipelines are examples of how to use the tasks. If you use a different CI/CD platform, you can use these Concourse files as examples of the inputs, outputs, and arguments used in each step in the workflow.
+ These Concourse pipelines are examples of how to use the tasks with Concourse for VMware Tanzu. Platform Automation Toolkit is supported when used with Concourse for VMware Tanzu on the Tanzu Platform. While the task definitions may be adaptable to other systems, only deployments using Concourse for VMware Tanzu are within the scope of VMware support.
```

**Impact:** Consistent messaging across all pipeline documentation.

---

### 4. `docs/getting-started.html.md.erb` (Getting Started)

**Line 11:** Clarified Concourse product name
```diff
- - For information about deploying Concourse with CredHub and User Account and Authentication (UAA),
+ - For information about deploying Concourse for VMware Tanzu with CredHub and User Account and Authentication (UAA),
```

**Impact:** Uses full product name to reinforce that it's a specific VMware product, not generic Concourse.

---

## What Was NOT Changed

### Preserved Technical References
- YAML configuration keys and file paths (unchanged)
- Technical task names and parameters (unchanged)
- Code examples and command syntax (unchanged)
- Links to Concourse CI documentation (unchanged - still needed for technical reference)

### Preserved Contextual References
- References to "Concourse" in technical contexts (e.g., "Concourse resources", "Concourse CLI")
- References to "pipelines" as a general automation concept
- References to "foundations" meaning Tanzu Operations Manager deployments

## Rationale for Approach

### Why These Specific Changes?

1. **Index page (Overview):** Most critical - sets expectations from the start
2. **Pipeline pages:** Where users are most likely to think "I can use this with my existing CI/CD"
3. **Getting Started:** Reinforces the product name early in the user journey

### Why NOT More Extensive Changes?

1. **"Foundations" unchanged:** In Platform Automation context, "foundations" specifically means "Tanzu Operations Manager deployments," not general infrastructure. Changing this would create confusion.

2. **"Pipelines" unchanged:** This is a generic automation term that applies to any CI/CD system. The context makes clear we're talking about Concourse pipelines.

3. **Technical Concourse references unchanged:** References like "Concourse resources," "Concourse tasks," "Concourse CLI" are technical terms that should remain as-is.

## Support Boundary Clarity

### Before These Changes:
- Docs suggested Platform Automation Toolkit could work with "different CI/CD platforms"
- Support boundaries were ambiguous
- Customers might reasonably expect support for off-platform use

### After These Changes:
- Clear statement: "Platform Automation Toolkit is supported when used with Concourse for VMware Tanzu on the Tanzu Platform"
- Acknowledges technical adaptability while clarifying support scope
- Sets appropriate customer expectations

## Next Steps

1. **Review with stakeholders:** Mike Jarvis, Anita, Engineering team
2. **Legal/SPD alignment:** Ensure these changes align with updated SPD language
3. **Customer communication:** Coordinate with Kathy K. for NatWest communication
4. **Merge and publish:** Once approved, merge to v5.4 and publish

## Questions for Dev Reviewer

Please review these questions and provide guidance:

### 1. Support Boundary Language - Is This Accurate?

**Current wording:** "Platform Automation Toolkit is supported when used with Concourse for VMware Tanzu on the Tanzu Platform."

- Is "on the Tanzu Platform" the correct phrasing? 
- Should it be "with Tanzu Operations Manager" or more specific?
- Does this align with what Engineering considers the support boundary?

### 2. "While task definitions may be adaptable..." - Too Permissive?

**Current wording:** "While the task definitions may be adaptable to other systems, only deployments using Concourse for VMware Tanzu are within the scope of VMware support."

- Does this acknowledge technical reality while setting boundaries appropriately?
- Or should we be more restrictive and not mention adaptability at all?
- Could this language create confusion or false expectations?

### 3. Are There Other Critical Pages Missing?

I focused on:
- Index (overview)
- Getting Started
- Pipeline reference pages

**Questions:**
- Are there other high-traffic pages that need similar clarifications?
- Should the task reference pages have support boundary notes?
- What about the how-to guides - do they need updates?

### 4. Technical Accuracy - "Concourse for VMware Tanzu"

I consistently used "Concourse for VMware Tanzu" as the product name.

- Is this the correct official product name?
- Should it be "Concourse for Tanzu" or "VMware Tanzu Concourse"?
- Are there places where just "Concourse" is still appropriate (e.g., technical references)?

### 5. Foundations Terminology

I did NOT change "foundations" to "Tanzu Platform foundations" because in Platform Automation context, "foundations" specifically means "Tanzu Operations Manager deployments."

- Is this the right call?
- Would changing "foundations" create confusion or clarity?
- Does "foundations" have a specific meaning in Platform Automation that should be preserved?

### 6. Impact on Existing Customers

**Concern:** Customers currently using Platform Automation Toolkit with other CI/CD systems will see this change.

- Should we add a migration note or deprecation timeline?
- Should there be a "Previously Supported" or "Legacy Use" section?
- How do we handle customers who are already off-platform?

### 7. Alignment with Other Docs

- Do these changes need to be coordinated with Concourse for VMware Tanzu docs?
- Should the Tanzu Operations Manager docs reference these support boundaries?
- Are there other product docs that reference Platform Automation Toolkit?

### 8. Version Applicability

These changes are on the `v5.4` branch.

- Should these changes be backported to earlier versions?
- Should there be a version note (e.g., "As of v5.4, support is limited to...")?
- Or is this a clarification of existing policy, not a new restriction?

### 9. Legal/SPD Review Needed?

- Do these doc changes need to be reviewed by Legal before merging?
- Should they be coordinated with the SPD updates Mike J. is working on?
- Are there any liability concerns with the "may be adaptable" language?

### 10. Customer-Facing Communication

For the NatWest situation specifically:

- Should there be a KB article or blog post explaining the support boundaries?
- Should existing customers be notified of this clarification?
- What's the timeline for publishing these changes relative to customer communication?

---

## Testing Recommendations

- Build docs locally to verify rendering
- Check all internal links still work
- Verify no YAML/code examples were inadvertently changed
- Review with someone unfamiliar with the changes to ensure clarity

## Files Changed

- `docs/index.html.md.erb`
- `docs/getting-started.html.md.erb`
- `docs/pipelines/resources.html.md.erb`
- `docs/pipelines/multiple-products.html.md.erb`

**Total:** 4 files, 5 specific changes

---

## For NatWest Situation

These changes support the "extended support" arrangement by:

1. Making clear what the standard support boundary is
2. Documenting that off-platform use is outside normal support scope
3. Providing a baseline for what "extended support" means (deviation from documented support)

The 6-12 month "off-ramp" can now be positioned as an exception to the clearly documented support policy.
