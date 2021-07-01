# Toolbox

Toolbox provides a standard set of build tools to help bootstrap infrastructure
projects. Toolbox is published as a [Docker image][01] and a [Makefile library][02]
that can be included into your projects to help ensure a consistent and reproducable
build experience.

## Features

- Standard build tool image containing Terraform, AWS CLI, Snyk, Shellcheck, etc
- Simplifies Terraform workspace configuration and management
- Auto-generation of Buildkite pipelines
- Make targets provide a consistent/reproducable way of invoking build tooling

## Getting Started

## Configuration

<!-- Links -->
[01]: Dockerfile
[02]: toolbox.mk
