# Agent Context Specification

## 1. Introduction

### 1.1 Purpose

Agent Context is a language-agnostic specification for providing and consuming contextual information from software packages to assist AI agents and other automated tools. This specification defines a standardized way for package authors to include supplementary documentation, examples, migration guides, and other contextual information that can be programmatically discovered and utilized.

### 1.2 Problem Statement

AI agents and automated tools working with software projects often lack access to the rich contextual information that package authors provide. While packages may have extensive documentation, examples, and best practices, this information is typically scattered across various sources and formats, making it difficult for automated tools to discover and utilize effectively.

### 1.3 Goals

- **Standardization**: Define a consistent structure for contextual information across different programming languages and ecosystems.
- **Discoverability**: Enable automated tools to programmatically find and access contextual information.
- **Separation of Concerns**: Clearly separate provider context from consumer context.
- **Extensibility**: Allow for future enhancements while maintaining backward compatibility.

## 2. Core Concepts

### 2.1 Context Provider

A **Context Provider** is any software package, library, or module that includes contextual information in its distribution. Context providers:

- Include a `context/` directory in their package root.
- Provide structured documentation and examples.
- Follow the file format specifications defined in this document.
- Version their context alongside their code.

### 2.2 Context Consumer

A **Context Consumer** is any project or tool that utilizes contextual information from its dependencies. Context consumers:

- Install context from their dependencies into a `.agents/context/` directory.
- May install skill-marked context documents into a `.agents/skills/` directory.
- Use tools to discover and access available context.
- Apply context based on file patterns and metadata.

### 2.3 Context Files

**Context Files** are structured documents that contain supplementary information about a package. They typically include:

- Documentation beyond basic API references.
- Configuration examples and templates.
- Migration guides between versions.
- Performance optimization tips.
- Security considerations.
- Troubleshooting guides.

### 2.4 Context Installation

**Context Installation** is the process of copying context files from dependencies into a consumer's local context directory, making them available for use by tools and AI agents.

## 3. Directory Structure

### 3.1 Provider Directory: `context/`

Context providers MUST include a `context/` directory in their package root. This directory:

- **Location**: Must be at the top level of the package (same level as main source directories).
- **Purpose**: Contains all contextual information provided by the package.
- **Distribution**: Must be included in the package's distribution artifacts.
- **Versioning**: Must be versioned alongside the package code.

Example structure:

```
package-root/
├── context/
│   ├── getting-started.md
│   ├── configuration.md
│   ├── troubleshooting.md
│   └── migration/
│       └── v2-to-v3.md
├── src/
└── package.json
```

### 3.2 Consumer Directory: `.agents/context/`

Context consumers SHOULD create a `.agents/context/` directory in their project root to store installed context. This directory:

- **Location**: Must be at the project root (typically where package manifests are located).
- **Purpose**: Contains context files copied from dependencies.
- **Organization**: Must organize context by package name in subdirectories.
- **Exclusion**: The generated `.agents/context/` directory SHOULD be excluded from version control. A Git integration SHOULD add local exclusions to `.git/info/exclude` so projects do not need to commit rules for generated files. Other project-owned files may live directly under `.agents/`.
- **Transient Nature**: Should contain only reproducible content that can be regenerated from installed packages and MUST NOT contain unique or modified files.

Example structure:

```
project-root/
├── .agents/context/
│   ├── package-a/
│   │   ├── getting-started.md
│   │   └── configuration.md
│   └── package-b/
│       └── troubleshooting.md
├── src/
└── package.json
```

### 3.3 Directory Separation Rationale

The separation between `context/` and `.agents/context/` serves several purposes:

- **Ownership**: `context/` is controlled by the project itself, `.agents/context/` contains external dependencies.
- **Isolation**: Prevents conflicts between different packages' context files.
- **Discoverability**: Makes it easy to find context for specific packages.
- **Maintenance**: Allows independent management of provided vs. consumed context.

## 4. Context File Format

### 4.1 File Extensions

Context files SHOULD use the following extensions:

- **`.md`**: Markdown files (primary format).
- **`.txt`**: Plain text files.
- **`.yaml`** or **`.yml`**: YAML configuration files.
- **`.json`**: JSON configuration files.

### 4.2 Markdown Context Files

Markdown files are the primary format for context files. They:

- MUST use valid Markdown syntax.
- SHOULD be named descriptively (e.g., `getting-started.md`, `configuration.md`).
- SHOULD include clear section headers for organization.

### 4.3 File Naming Conventions

Context files SHOULD follow these naming conventions:

- Use lowercase with hyphens for word separation.
- Be descriptive and specific.
- Group related files in subdirectories when appropriate.

Common file names:

- `getting-started.md`
- `configuration.md`
- `troubleshooting.md`
- `performance.md`
- `security.md`
- `migration-guide.md`

### 4.4 Skill Documents

A context provider may distribute an Agent Skill as a Markdown document directly inside `context/`. The document MUST use YAML front matter with `type: skill` and a non-empty `description`. Its filename, without the `.md` extension, is the local skill name. A directory with the same name MAY contain skill resources. Consumers MUST prefix the local name with the lowercase provider package name (with underscores normalized to hyphens) and a hyphen to produce the installed skill name. Installed names MUST use lowercase ASCII letters, digits, and single hyphens, contain 1–64 characters, and begin and end with a letter or digit. Descriptions MUST contain 1–1,024 characters after trimming whitespace. Consumers MUST validate these fields and preserve additional skill metadata; generated installed names take precedence over a source `name` field.

Consumers that support skills MUST install the document as `.agents/skills/<package-name>-<local-name>/SKILL.md`, with the installed name and `description` in its front matter. Files in the matching resource directory MUST be copied into that skill directory. Skill documents and their resources MUST NOT also be copied into `.agents/context/` or included in the generated context index.

Dependency-installed skill directories SHOULD be excluded from version control, while project-owned skills in `.agents/skills/` SHOULD remain trackable. Git integrations SHOULD add exact dependency-installed skill paths to `.git/info/exclude` rather than ignore the entire `.agents/skills/` directory. They SHOULD mark generated entries with comments and preserve user-authored rules outside that marked section. Any generated skill ownership registry SHOULD also be excluded from version control.

## 5. Discovery and Installation

### 5.1 Discovery Process

Tools MUST be able to discover context by:

1. **Package Scanning**: Examining installed packages for `context/` directories.
2. **Metadata Extraction**: Reading package manifests to identify context-providing packages.
3. **File Enumeration**: Listing available context files for each package.

The discovery process SHOULD integrate with the target language's package management system to:

- Locate installed packages and their installation paths.
- Read package metadata to identify packages that provide context.
- Enumerate available context files within discovered packages.

### 5.2 Installation Process

Context installation MUST follow these principles:

1. **Copy Strategy**: Context files SHOULD be copied rather than symlinked.
2. **Namespace Isolation**: Each package's ordinary context MUST be installed in its own subdirectory.
3. **Preserve Structure**: The internal structure of ordinary context files MUST be preserved.
4. **Skill Separation**: Skill documents and their resources MUST be installed as skills only, not duplicated as ordinary context.

### 5.3 Installation Algorithm

```
FOR each package with context:
  FOR each file in package/context/:
    IF file is a skill document or belongs to a skill resource directory:
      IF the consumer supports skills:
        INSTALL the document as .agents/skills/skill-name/SKILL.md
        COPY its matching resource directory into that skill directory
      ELSE:
        SKIP it
    ELSE:
      COPY it into .agents/context/package-name/, preserving its relative path
END
```

## 6. Generated Index and Repository Ownership

Consumers SHOULD generate `.agents/context/index.md` with links relative to that file. Context installation MUST NOT create or modify the repository owner's `agents.md`. Owners can link to the generated index and instruct agents to read relevant installed guidance.

Ordinary documents need no front matter. Consumers SHOULD use a document's first heading as its title (falling back to the filename) and its first prose sentence as its description. A non-empty YAML `description` takes precedence over prose. Unrelated ordinary-document metadata MUST be tolerated. Skill resource files are opaque assets and MUST NOT be parsed as context documents.

A provider MAY supply `context/index.yaml` with `description` and a `files` sequence containing `path`, `title`, and `description`. Supporting consumers SHOULD preserve explicit ordering and overrides, omit missing or skill-only paths, and append unlisted ordinary documents. Fallback ordering is getting-started, overview, usage, configuration, migration, troubleshooting, debugging, then alphabetical order.

## 7. Shared Skill Ownership Index

Consumers MUST record dependency-installed skill ownership in `.agents/skills/.agent-context-skills.json`:

```json
{
  "version": 2,
  "skills": {
    "provider-workflow": {
      "ecosystem": "cargo",
      "package": "provider",
      "version": "1.0.0"
    }
  }
}
```

Ruby gems use `ecosystem: gem`; Cargo crates use `ecosystem: cargo`. Each installer MUST preserve foreign ecosystem entries. A full refresh reconciles only its ecosystem; a package refresh reconciles only that ecosystem and package; installing one named skill MUST preserve other owned skills. Providers removed from the dependency graph and providers that become empty MUST be included in full reconciliation.

Existing unowned destinations and destinations owned by another ecosystem or package MUST NOT be replaced. Installers MUST validate the selected sources and collisions, stage skill files, and preserve the previous directories and ownership index when copying or committing a replacement fails. Shared index writes MUST use atomic replacement.

Version-one JSON ownership has implicit Cargo ownership and MUST migrate to version two when rewritten.

Git integrations SHOULD maintain one marked exclusion block covering generated context, ownership files, and exact dependency-owned skill directories from all ecosystems. They MUST preserve user rules and leave repository-owned instructions and skills trackable.
