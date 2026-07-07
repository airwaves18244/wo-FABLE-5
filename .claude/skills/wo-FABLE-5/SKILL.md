```markdown
# wo-FABLE-5 Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches you the core development patterns and conventions used in the `wo-FABLE-5` TypeScript repository. You'll learn about file organization, import/export styles, commit message habits, and how to write and locate tests. While no specific framework or automated workflows are detected, this guide will help you maintain consistency and productivity within this codebase.

## Coding Conventions

### File Naming
- Use **kebab-case** for all file names.
  - Example:  
    ```
    user-profile.ts
    data-fetcher.test.ts
    ```

### Import Style
- Use **relative imports** for referencing other modules.
  - Example:
    ```typescript
    import { fetchData } from './data-fetcher';
    ```

### Export Style
- Use **named exports** for functions, classes, and constants.
  - Example:
    ```typescript
    // In user-profile.ts
    export function getUserProfile(id: string) { ... }
    ```

    ```typescript
    // Importing elsewhere
    import { getUserProfile } from './user-profile';
    ```

### Commit Patterns
- Commit messages are **freeform** (no strict prefixes).
- Typical message length: ~55 characters.
  - Example:
    ```
    Add error handling to data fetcher module
    ```

## Workflows

### Adding a New Module
**Trigger:** When you need to add a new feature or utility.
**Command:** `/add-module`

1. Create a new file using kebab-case (e.g., `feature-name.ts`).
2. Use named exports for all public functions or constants.
3. Use relative imports to include dependencies.
4. Write corresponding tests in a `.test.ts` file.

### Writing Tests
**Trigger:** When you add or update functionality.
**Command:** `/write-test`

1. Create a test file with the same base name as the module, ending with `.test.ts` (e.g., `feature-name.test.ts`).
2. Write tests using your preferred framework (not specified in the repo).
3. Use relative imports to bring in the module under test.

### Refactoring Code
**Trigger:** When improving or restructuring existing code.
**Command:** `/refactor`

1. Update file names to kebab-case if needed.
2. Ensure all imports are relative and exports are named.
3. Update or add tests to reflect changes.

## Testing Patterns

- Test files follow the pattern: `*.test.ts`
  - Example: `user-profile.test.ts`
- The testing framework is **not specified**; use your team's standard.
- Tests are co-located with source files or in the same directory.

## Commands

| Command        | Purpose                                      |
|----------------|----------------------------------------------|
| /add-module    | Create a new module following conventions    |
| /write-test    | Add or update a test file for a module       |
| /refactor      | Refactor code to match repo conventions      |
```