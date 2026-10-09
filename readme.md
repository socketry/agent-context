# Agent::Context

Discover and install practical guidance and skills shipped by Ruby gems.

## Installation

```sh
bundle add agent-context
bundle exec bake agent:context:install
```

Installation copies ordinary context into `.agents/context/<gem>/`, installs dependency skills into `.agents/skills/`, and generates `.agents/context/index.md`. Repository-owned `agents.md` is preserved.

## Commands

```sh
bake agent:context:list
bake agent:context:list --gem async
bake agent:context:show --gem async --file getting-started
bake agent:context:install
bake agent:context:install --gem async
bake agent:context:index
bake agent:context:skill:list
bake agent:context:skill:show --gem provider --skill provider-workflow
bake agent:context:skill:install
bake agent:context:skill:install --gem provider --skill provider-workflow
```

`agent-context` includes skill discovery and installation directly; the separate `agent-skills` gem is deprecated and is no longer needed. Remove it from your Gemfile. Replace the former `agent:skills:*` commands with `agent:context:skill:*`.

## Agent Instructions and Version Control

Add a stable link to `.agents/context/index.md` in your repository-owned `agents.md`, together with instructions to read relevant installed guides. Run installation after changing dependencies. When migrating from an older generated `agents.md`, replace its generated dependency listing with this link while retaining project instructions.

Installation maintains a marked block in the local Git exclude file, discovered through `git rev-parse --git-path info/exclude`. It excludes generated context, ownership files, and exact dependency-installed skill directories. Project-owned instructions and skills under `.agents/` remain trackable. Remove any blanket `/.agents/` rule from your project's `.gitignore` when adopting this layout. Re-run installation in each checkout.

## Providing Context and Skills

Include a top-level `context/` directory in your packaged gem. Write focused guides with a clear heading and first sentence. Optional YAML `description` overrides the prose summary; other document metadata is tolerated.

A root-level context document can declare a skill:

```markdown
---
type: skill
description: Run the provider's workflow when preparing a new project.
license: MIT
---

# Workflow

Follow these instructions.
```

`context/workflow.md` from gem `provider` becomes `.agents/skills/provider-workflow/SKILL.md`. Resources in `context/workflow/` are copied alongside the instructions. Skill sources and resources are excluded from ordinary context and its index. Installed names have a 64-character limit; descriptions have a 1,024-character limit. Additional skill metadata is preserved.

Skills are discovered only through `type: skill` metadata in `context/*.md`, matching `bake-agent-context-rust`. Include `context/**/*` in your gem's file list. To migrate a `skills/<name>/SKILL.md` bundle, move its instructions to `context/<name>.md`, add `type: skill` to the front matter, and move its resources to `context/<name>/`. Installed skill names become package-prefixed.

Providers can retain `context/index.yaml` to control guide ordering and metadata. Explicit entries take precedence, missing and skill-only entries are skipped, and unlisted guides are appended.

## Ownership and Updates

Skills use the shared version-two JSON ownership index at `.agents/skills/.agent-context-skills.json`. Owners record ecosystem, package, and version. Ruby refreshes preserve Cargo-owned entries and project-owned directories. Skill replacements are staged; failed copying or committing preserves the previous installation. A full refresh removes stale gem-owned skills, including skills from removed or empty providers.

Legacy Ruby YAML ownership and version-one Cargo JSON ownership migrate to the shared format. Ruby's legacy ownership file is retired after successful installation.

See [the portable specification](specification.md) and [Getting Started](guides/getting-started/readme.md).

## Development

```sh
bundle exec sus
bundle exec rubocop
```

See [releases.md](releases.md) and [license.md](license.md).

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
