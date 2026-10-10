# Agent::Context

Provides tools for installing and managing context files and skills from Ruby gems for AI agents, and generating `.agents/context/index.md`.

[![Development Status](https://github.com/socketry/agent-context/workflows/Test/badge.svg)](https://github.com/socketry/agent-context/actions?workflow=Test)

## Overview

This gem allows you to install and manage context files from other gems. Gems can provide context files in a `context/` directory in their root, which can contain documentation, configuration examples, migration guides, and other contextual information for AI agents.

When you install context from gems, ordinary guides are placed in `.agents/context/` and dependency skills in `.agents/skills/`. The generated `.agents/context/index.md` links to the guides.

## Quick Start

Add the gem to your project and install context from all available gems:

``` bash
$ bundle add agent-context
$ bake agent:context:install
```

This workflow:

  - Adds the `agent-context` gem to your project.
  - Installs context files from all gems into `.agents/context/`.
  - Installs metadata-declared skills into `.agents/skills/`.
  - Generates `.agents/context/index.md` with a comprehensive overview.
  - Follows the <https://agents.md> specification for agentic coding tools.

## Context

This gem provides its own context files in the `context/` directory, including:

  - `getting-started.md` - Comprehensive guide for using and providing context files and skills.
  - [`usage.md`](context/usage.md) - Agent instructions for finding dependency guidance and managing context and skills, installed as the `agent-context-usage` skill.

When you install context from other gems, they will be placed in `.agents/context/` and referenced in `.agents/context/index.md`.

## Usage

Please see the [project documentation](https://ioquatix.github.io/agent-context/) for more details.

  - [Getting Started](https://ioquatix.github.io/agent-context/guides/getting-started/index) - This guide explains how to use `agent-context`, a tool for discovering and installing contextual information from Ruby gems to help AI agents.

### Installation

Add the `agent-context` gem to your project:

``` bash
$ bundle add agent-context
```

### Commands

#### Install Context (Primary Command)

Install ordinary context and skills from all available gems and update `.agents/context/index.md`:

``` bash
$ bake agent:context:install
```

Install context from a specific gem:

``` bash
$ bake agent:context:install --gem async
```

#### List available context

List all gems that have context available:

``` bash
$ bake agent:context:list
```

List context files for a specific gem:

``` bash
$ bake agent:context:list --gem async
```

#### Show context content

Show the content of a specific context file:

``` bash
$ bake agent:context:show --gem async --file thread-safety
```

#### Refresh the Context Index

Refresh the index from installed context:

``` bash
$ bake agent:context:index
```

#### Skills

List, show, or install metadata-declared dependency skills:

``` bash
$ bake agent:context:skill:list
$ bake agent:context:skill:show --gem provider --skill provider-workflow
$ bake agent:context:skill:install
$ bake agent:context:skill:install --gem provider --skill provider-workflow
```

`agent-context` includes skill discovery and installation directly. Use it for Ruby dependency skills; the standalone `agent-skills` gem is deprecated.

## Version Control

Add a stable link to `.agents/context/index.md` in your repository-owned `agents.md`, together with instructions to read relevant installed guides. Run installation after changing dependencies. When migrating from an older generated `agents.md`, replace its generated dependency listing with this link while retaining project instructions.

Installation maintains a marked block in the local Git exclude file, discovered through `git rev-parse --git-path info/exclude`. It excludes generated context, ownership files, and exact dependency-installed skill directories. Track project-owned instructions and skills under `.agents/`. Remove any blanket `/.agents/` rule from your project's `.gitignore` when adopting this layout. Re-run installation in each checkout.

## Providing Context in Your Gem

To provide context files in your gem, create a `context/` directory in your gem's root:

    your-gem/
    ├── context/
    │   ├── getting-started.md
    │   ├── usage.md
    │   ├── configuration.md
    │   └── index.yaml (optional)
    ├── lib/
    └── your-gem.gemspec

### Optional: Custom Index File

You can provide a custom `index.yaml` file to control ordering and metadata:

``` yaml
description: "Your gem description from gemspec"
version: "1.0.0"
files:
  - path: getting-started.md
    title: "Getting Started"
    description: "Quick start guide"
  - path: usage.md
    title: "Usage Guide"
    description: "Detailed usage instructions"
```

Installation generates `.agents/context/index.md` directly from Markdown headings, prose summaries, and document ordering, with the gem summary supplying the package description. A provider-authored `index.yaml` customizes these values.

### Providing Skills

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

`context/workflow.md` from gem `provider` becomes `.agents/skills/provider-workflow/SKILL.md`. Resources in `context/workflow/` are copied alongside the instructions. Installed names have a 64-character limit; descriptions have a 1,024-character limit. The generated instructions include additional skill metadata.

Skills are discovered through `type: skill` metadata in `context/*.md`, matching `bake-agent-context-rust`. Include `context/**/*` in your gem's file list. Installed skill names become package-prefixed.

## Ownership and Updates

Each installed skill directory contains `skill.json` with its provider ecosystem, package, and version. Ruby refreshes reconcile gem-owned skills. Skill updates use staged replacements with rollback on failure. A full refresh removes stale gem-owned skills, including skills from removed or empty providers.

See [the portable specification](specification.md) and [Getting Started](guides/getting-started/readme.md).

## Releases

Please see the [project releases](https://ioquatix.github.io/agent-context/releases/index) for all releases.

### v0.3.0

  - Rename `agent.md` -\> `agents.md`.

### v0.2.0

  - Don't limit description length.

## See Also

  - [Bake](https://github.com/ioquatix/bake) — The bake task execution tool.

### Gems With Context Files

  - [Async](https://github.com/socketry/async)
  - [Decode](https://github.com/ioquatix/decode)
  - [Falcon](https:///github.com/socketry/falcon)
  - [Sus](https://github.com/socketry/sus)

## Contributing

We welcome contributions to this project.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature.'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new pull request.

### Running Tests

To run the test suite:

``` bash
$ bundle exec sus
```

### Making Releases

To make a new release:

``` bash
$ bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
