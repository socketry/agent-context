---
type: skill
description: Install and navigate guidance and skills from Ruby gem dependencies, or publish context and skills from a gem using agent-context.
---

# Using and Providing Context

Use `agent-context` to find practical guidance shipped by Ruby gem dependencies and make package guidance available to downstream agents.

## Use Dependency Guidance

Follow the repository's agent instructions and read `.agents/context/index.md` to find installed dependency guidance. Use its package descriptions, document titles, and summaries to select the guides relevant to the task, then read those guides before changing code that uses the package.

If the index or relevant installed files are missing, run `bundle exec bake agent:context:install` from the consuming project. Run it again after changing dependencies. It installs ordinary context and skills from resolved gems and refreshes `.agents/context/index.md`. The consuming gem's own source context is excluded from a full dependency install.

To inspect a provider or install only its guidance:

```bash
bundle exec bake agent:context:list
bundle exec bake agent:context:list --gem async
bundle exec bake agent:context:show --gem async --file thread-safety
bundle exec bake agent:context:install --gem async
```

`show` reads the provider's source file without installing it; the `.md` extension is optional. `install --gem NAME` installs both ordinary context and skills from that provider. Use `bundle exec bake agent:context:index` to regenerate the index from already installed context.

Ordinary context is copied to `.agents/context/GEM/`. The index links to Markdown guides using their headings and prose summaries. Installation preserves repository-owned `agents.md`; add a stable link to `.agents/context/index.md` there when configuring repository instructions.

## Use Dependency Skills

Skills contain procedures for particular tasks and are installed under `.agents/skills/`. Use the matching skill's instructions and resources when its description applies to the work. Skill sources are omitted from ordinary context and its index.

```bash
bundle exec bake agent:context:skill:list
bundle exec bake agent:context:skill:show --gem agent-context --skill agent-context-usage
bundle exec bake agent:context:skill:install
bundle exec bake agent:context:skill:install --gem agent-context --skill agent-context-usage
```

Skill names are prefixed by the provider gem. `skill:install` refreshes all dependency skills by default; `--gem NAME` selects one provider and `--skill NAME` selects one installed skill name. Selecting a single skill leaves other installed skills intact. This document installs as `agent-context-usage/SKILL.md`.

## Keep Sources and Installed Files Separate

The provider's tracked `context/` directory is source content. Installed dependency copies under `.agents/context/` and `.agents/skills/` are generated; edit provider sources and reinstall to update them. Keep repository-only instructions and project-owned skills in the consuming repository.

Installation maintains local Git exclusions for generated context, the skill ownership index, and exact dependency-installed skill directories. Project-owned skills remain trackable. Remove blanket `/.agents/` ignore rules when adopting this layout.

The `.agents/skills/.agent-context-skills.json` file records installed ownership. Skill discovery comes from source document metadata. Full Ruby skill refreshes remove stale gem-owned skills while preserving Cargo-owned and project-owned skills; copying or replacing skills preserves the previous installation if it fails.

## Publish Context and Skills

Put focused Markdown guides directly in the gem's `context/` directory, using descriptive lowercase filenames. Give each guide a clear heading and first prose sentence. YAML front matter can override its summary with `description`. A provider-authored `index.yaml` can override ordering, titles, and descriptions; installation preserves it and generates the Markdown index directly without creating provider YAML.

To publish a skill, add `context/workflow.md` with metadata describing when to use it:

```markdown
---
type: skill
description: Set up a project using this gem's conventions.
---

# Workflow

Follow the setup instructions.
```

The filename supplies the local name: gem `provider` installs this document as `.agents/skills/provider-workflow/SKILL.md`. Put companion resources in `context/workflow/`; they are copied alongside the generated instructions. The installer supplies the required skill `name`, removes the source `type`, and preserves additional metadata. Keep the resources directory free of a top-level `SKILL.md`, which the installer generates.

Include `context/**/*` in the gemspec's packaged files. Installed skill names must use lowercase ASCII letters, digits, and single hyphens, with at most 64 characters including the package prefix. Descriptions must contain 1–1,024 characters and explain the task that should activate the skill.
