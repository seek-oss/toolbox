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

To use Toolbox, download the latest released version of [toolbox.mk][02] from the
[releases][03] page into the root of your project. The following Bash script will
do the same thing.

```bash
curl -s https://api.github.com/repos/seek-oss/toolbox/releases/latest \
  | jq -r '.assets[0].browser_download_url' \
  | xargs curl -Lso toolbox.mk
```

Then, include `toolbox.mk` from your project's Makefile.

```makefile
# Makefile
include toolbox.mk
```

You can now run `make help` to show the available Toolbox commands. Most of the
commands require a Toolbox configuration file which is described below.

To keep Toolbox up to date, you can run `make toolbox-upgrade` to install the
latest released version.

## Configuration

Each project that uses Toolbox needs to define a configuration file that tells
Toolbox about your project. Toolbox will search for a configuration file in the
root of your project in the following order of names: `toolbox.yaml`, `toolbox.yml`,
`.toolbox.yaml`, `.toolbox.yml`. You can use the environment variable
`TOOLBOX_CONFIG_FILE` if you want to use a custom file path.

An example annotated configuration file is shown below. The schema can be found
[here][04].

```yaml
# (Optional)
# Terraform configuration section.
terraform:
  # (Optional)
  # Terraform linting section. This section configures the behaviour of the
  # `terraform fmt` command.
  lint:
    # (Optional)
    # Buildkite queue that is targetted by the lint operation. If this queue is omitted,
    # the lint operation is excluded from the Buildkite pipeline.
    queue: development

  # (Optional)
  # Terraform validation section. This section configures the behaviour of the
  # `terraform validate` command.
  validate:
    # (Optional) Buildkite queue that is targetted by the validate operation. If this
    # queue is omitted, the validate operation is excluded from the Buildkite pipeline.
    queue: development

  # (Optional)
  # Terraform workspace configuration section.
  # Each Terraform workspace represents a deployent target that can be planned and applied.
  workspaces:
  - # (Required)
    # Name of the workspace. This must be unique within the array of workspaces.
    name: us-west-1-development
    # (Optional)
    # Path to the variables file that corresponds to this workspace.
    var_file: config/us-west-1/development.tfvars
    # (Optional)
    # ID of the AWS account that this workspace is deployed to. This field is used to protect
    # against being authenticated against the wrong account. If this field is omitted, this
    # safety check will not be performed.
    aws_account_id: "111111111111"
    # (Optional)
    # Buildkite queue that is targetted by the Terraform operations on this workspace.
    # If this queue is omitted, this workspace will be excluded from the Buildkite pipeline.
    queue: development
    # (Optional)
    # Whether this workspace corresponds to a production environment. This field is used to
    # order deployments within the Buildkite pipeline so that non-production workspaces are
    # deployed before production workspaces.
    is_production: false

# (Optional)
# Shell script configuration section.
shell:
  (Optional)
  # Shell linting section. This section configures the behaviour of the shellcheck and shfmt
  # commands which can either be run indendently via `make shell-shellcheck` and `make-shfmt`,
  # respectively, or together via `make shell-lint`.
  lint:
    # (Optional)
    # Buildkite queue that is targetted by the lint operation (that runs both shellcheck and shfmt).
    # If this queue is omitted, the lint operation is excluded from the Buildkite pipeline.
    queue: development

# (Optional)
# Snyk configuration section.
snyk:
  # (Required)
  # Name of the Snyk organisation to which projects should be assigned.
  org: my-org
  # (Required)
  # ID of the AWS secret that holds the Snyk API token.
  secret_id: snyk/api-token
  # (Optional)
  # Snyk application test section.
  app_test:
    # (Optional)
    # Buildkite queue that is targetted by the application test operation. If this queue is omitted,
    # Snyk application tests will be excluded from the Buildkite pipeline.
    queue: development
    # (Optional)
    # Whether the application test should run in "warning mode" and always pass so as not to block
    # the Buildkite pipeline. Defaults to false.
    always_pass: false

  # (Optional)
  # Snyk infrastructure test section.
  iac_test:
    # (Optional)
    # Buildkite queue that is targetted by the application test operation. If this queue is omitted,
    # Snyk application tests will be excluded from the Buildkite pipeline.
    queue: development
    # (Optional)
    # Whether the application test should run in "warning mode" and always pass so as not to block
    # the Buildkite pipeline. Defaults to false.
    always_pass: false
```

<!-- Links -->
[01]: Dockerfile
[02]: toolbox.mk
[03]: https://github.com/seek-oss/toolbox/releases
[04]: lib/schema.json


<!--
TODO:
- Cater for interactive commands like: console, import, etc.
- Test destroy
- Put things under the buildkite: field that should be
- Document buildkite section
- Document Buildkite artifacts
- Fix toolbox-upgrade
-->
