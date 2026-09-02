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
- **Exclusion**: The generated `.agents/` directory SHOULD be excluded from version control (e.g., in `.gitignore`).
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
2. **Namespace Isolation**: Each package's context MUST be installed in its own subdirectory.
3. **Preserve Structure**: The internal structure of the `context/` directory MUST be preserved.

### 5.3 Installation Algorithm

```
FOR each package with context:
  CREATE directory .agents/context/package-name/
  COPY all files recursively from package/context/ to .agents/context/package-name/
END
```
