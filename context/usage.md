---
type: skill
description: Install and navigate guidance and skills from Ruby gem dependencies, or publish context and skills from a gem using agent-context.
---

# Using and Providing Context

Use `agent-context` to find practical guidance shipped by Ruby gem dependencies and make package guidance available to downstream agents.

## Use Dependency Guidance

Follow the repository's agent instructions and read `.agents/context/index.md` to find installed dependency guidance. Use its package descriptions, document titles, and summaries to select the guides relevant to the task, then read those guides before changing code that uses the package.

If the index or relevant installed files are missing, run `bundle exec bake agent:context:install` from the consuming project. Run it again after changing dependencies. It installs ordinary context and skills from resolved dependency gems and refreshes `.agents/context/index.md`.

To inspect or install guidance from a specific provider:

```bash
bundle exec bake agent:context:list
bundle exec bake agent:context:list --gem async
bundle exec bake agent:context:show --gem async --file thread-safety
bundle exec bake agent:context:install --gem async
```

`show` reads the provider's source file; the `.md` extension is optional. `install --gem NAME` installs both ordinary context and skills from that provider. Use `bundle exec bake agent:context:index` to regenerate the index from already installed context.

Ordinary context is copied to `.agents/context/GEM/`. The index links to Markdown guides using their headings and prose summaries. Add a stable link to `.agents/context/index.md` in the repository's `agents.md` when configuring repository instructions.

## Use Dependency Skills

Skills contain procedures for particular tasks and are installed under `.agents/skills/`. Use the matching skill's instructions and resources when its description applies to the work.

```bash
bundle exec bake agent:context:skill:list
bundle exec bake agent:context:skill:show --gem agent-context --skill agent-context-usage
bundle exec bake agent:context:skill:install
bundle exec bake agent:context:skill:install --gem agent-context --skill agent-context-usage
```

Skill names are prefixed by the provider gem. `skill:install` refreshes all dependency skills by default; `--gem NAME` selects one provider and `--skill NAME` selects one installed skill name. This document installs as `agent-context-usage/SKILL.md`.

## Keep Sources and Installed Files Separate

The provider's tracked `context/` directory is source content. Installed dependency copies under `.agents/context/` and `.agents/skills/` are generated; edit provider sources and reinstall to update them. Keep repository-only instructions and project-owned skills in the consuming repository.

Installation maintains local Git exclusions for generated context, the skill ownership index, and exact dependency-installed skill directories. Track project-owned skills under `.agents/skills/` and remove blanket `/.agents/` ignore rules when adopting this layout.

The `.agents/skills/.agent-context-skills.json` file records installed ownership. Skill discovery comes from source document metadata. Full Ruby skill refreshes reconcile gem-owned skills and remove stale entries. Skill updates use staged replacements with rollback on failure.

## Publish Context and Skills

Put focused Markdown guides directly in the gem's `context/` directory, using descriptive lowercase filenames. Give each guide a clear heading and first prose sentence. YAML front matter can override its summary with `description`. Installation generates the Markdown index directly from these documents and uses provider-authored `index.yaml` to customize ordering, titles, and descriptions.

To publish a skill, add `context/workflow.md` with metadata describing when to use it:

```markdown
---
type: skill
description: Set up a project using this gem's conventions.
---

# Workflow

Follow the setup instructions.
```

The filename supplies the local name: gem `provider` installs this document as `.agents/skills/provider-workflow/SKILL.md`. Put companion resources in `context/workflow/`; they are copied alongside the generated instructions. The installer supplies the required skill `name`, removes the source `type`, and includes additional metadata. The top-level `SKILL.md` is reserved for the generated instructions.

Include `context/**/*` in the gemspec's packaged files. Installed skill names must use lowercase ASCII letters, digits, and single hyphens, with at most 64 characters including the package prefix. Descriptions must contain 1–1,024 characters and explain the task that should activate the skill.
