# Getting Started

This guide explains how to install package guidance and skills using `agent-context`.

## Installation

```sh
bundle add agent-context
bundle exec bake agent:context:install
```

The installer copies guides to `.agents/context/<gem>/`, installs skills under `.agents/skills/`, and writes `.agents/context/index.md`. It preserves your repository-owned `agents.md`. Add a stable link to the generated index there and instruct agents to read relevant guides.

## Commands

```sh
bake agent:context:list
bake agent:context:show --gem async --file getting-started
bake agent:context:install --gem async
bake agent:context:index
bake agent:context:skill:list
bake agent:context:skill:install --gem provider --skill provider-workflow
bake agent:context:skill:show --gem provider --skill provider-workflow
```

The main install command installs ordinary context and skills. The skill commands use installed, package-prefixed names for context-declared skills. The former `agent:skills:*` commands are removed.

## Migrating from Agent Skills

Skill discovery and installation are built into `agent-context`. Replace the `agent-skills` dependency in your Gemfile with `agent-context`, then run `bundle install`. Use `agent:context:skill:*` in place of `agent:skills:*`. Move existing `skills/<name>/SKILL.md` instructions to `context/<name>.md`, add `type: skill` to the front matter, and move their resources to `context/<name>/`. Installed names become package-prefixed. Ownership from `.agent-skills.yaml` migrates automatically during installation.

## Provider Layout

Put ordinary guides in the packaged gem's top-level `context/` directory. Use a clear heading and first prose sentence. An optional YAML `description` overrides the summary. A provider-authored `index.yaml` can still control ordering, titles, and descriptions.

To provide a skill, put a Markdown document directly inside `context/`:

```markdown
---
type: skill
description: Follow the workflow when setting up this package.
---

# Workflow

Follow the setup instructions.
```

`context/workflow.md` in gem `provider` installs as `provider-workflow/SKILL.md`. The matching `context/workflow/` directory supplies resources. Additional skill metadata is preserved. Installed names must use lowercase ASCII letters, digits and single hyphens, with at most 64 characters. Descriptions must contain 1–1,024 characters.

Include the complete source directories in your gem's packaged files. Skill documents and resource trees are installed only as skills.

## Ownership and Version Control

Generated context and dependency-owned skills are reproducible. Edit their provider sources, then reinstall. Project-owned skills and instructions can live under `.agents/` and remain version controlled.

Installation maintains local Git exclusions for generated context, ownership files, and exact dependency-installed skill directories. Remove blanket `/.agents/` ignore rules when adopting this layout.

The shared ownership index records ecosystem, package, and version. Full Ruby refreshes remove stale gem-owned skills and preserve Cargo-owned skills. A selected-skill install leaves other skills intact. Failed skill copying or replacement preserves the previous files and index. Legacy ownership files migrate on successful installation.

When migrating an old generated `agents.md`, replace its generated dependency listing with a stable link to `.agents/context/index.md`, preserving your project instructions.
