# Agent::Context

Provides tools for installing and managing context files from Ruby gems for AI agents, and generating `agents.md` files following the <https://agents.md> specification.

[![Development Status](https://github.com/socketry/agent-context/workflows/Test/badge.svg)](https://github.com/socketry/agent-context/actions?workflow=Test)

## Overview

This gem allows you to install and manage context files from other gems. Gems can provide context files in a `context/` directory in their root, which can contain documentation, configuration examples, migration guides, and other contextual information for AI agents.

When you install context from gems, they are placed in the `.agents/context/` directory and an `agents.md` file is generated or updated to provide a comprehensive overview for AI agents.

## Quick Start

Add the gem to your project and install context from all available gems:

``` bash
$ bundle add agent-context
$ bake agent:context:install
```

This workflow:

  - Adds the `agent-context` gem to your project.
  - Installs context files from all gems into `.agents/context/`.
  - Generates or updates `agents.md` with a comprehensive overview.
  - Follows the <https://agents.md> specification for agentic coding tools.

## Context

This gem provides its own context files in the `context/` directory, including:

  - `usage.md` - Comprehensive guide for using and providing context files.

When you install context from other gems, they will be placed in the `.agents/context/` directory and referenced in `agents.md`.

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

Install context from all available gems and update `agents.md`:

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

## Version Control

The `.agents/` directory contains generated files and should be excluded from version control. The generated `agents.md` index should be committed:

  - `agents.md` is user-facing documentation that should be versioned.
  - `.agents/context/` can be restored by running `bake agent:context:install`.
  - Ignoring the entire `.agents/` directory covers other generated agent resources too.

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

If no `index.yaml` is provided, one will be generated automatically from your gemspec and markdown files.

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
