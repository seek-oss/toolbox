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
terraform:
  lint:
    queue: development
  validate:
    queue: development
  workspaces:
  - name: us-west-1-development
    var_file: config/us-west-1/development.tfvars
    aws_account_id: "111111111111"
    queue: development
    is_production: false
  - name: us-west-1-production
    var_file: config/us-west-1/production.tfvars
    aws_account_id: "222222222222"
    queue: production
    is_production: true
  - name: us-west-2-production
    var_file: config/us-west-2/production.tfvars
    aws_account_id: "222222222222"
    queue: production
    is_production: true
shell:
  lint:
    queue: development
snyk:
  org: my-org
  secret_id: snyk/api-token
  app_test:
    queue: development
    always_pass: false
  iac_test:
    queue: development
    always_pass: false
```

<!-- Links -->
[01]: Dockerfile
[02]: toolbox.mk
[03]: https://github.com/seek-oss/toolbox/releases
[04]: lib/schema.json
