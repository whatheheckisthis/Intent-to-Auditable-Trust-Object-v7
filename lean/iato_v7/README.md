# IATO_V7 Lean Package

This package is intentionally configured as a plain Lean/Lake project. It does
not ship CI/CD wrapper scripts, installer scripts, or exported build-time
environment variables.

## Toolchain

Install Lean/Lake outside the repository with your normal Lean tooling. The
package toolchain is declared in:

```text
lean-toolchain
```

## Build and test

Run Lake directly from this package directory:

```bash
cd lean/iato_v7
lake update
lake build
lake test
```

To build a specific target, pass it directly to Lake:

```bash
cd lean/iato_v7
lake build test-basic
lake exe test-basic
```
