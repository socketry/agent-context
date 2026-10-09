# Agent Instructions

Follow repository-owned instructions in `agents.md`, if present. Read relevant dependency guidance from `.agents/context/index.md`. If generated guidance is missing, run `bundle exec bake agent:context:install`.

Package guides belong in `context/`; repository-only instructions and project-owned skills belong in `.agents/`. Installation preserves `agents.md` and maintains local Git exclusions for generated files.
