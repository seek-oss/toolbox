FROM alpine:3.23

ARG TARGETARCH

ARG TOOLBOX_VERSION
ENV TOOLBOX_VERSION="${TOOLBOX_VERSION}"
ENV TOOLBOX_HOME=/usr/local/share/toolbox

ARG TERRAFORM_VERSION=1.12.2
ARG SHELLCHECK_VERSION=0.10.0
ARG SHFMT_VERSION=3.12.0
ARG YQ_VERSION=4.45.4
ARG SCHMA_VERSION=1.0.0
ARG SNYK_VERSION=1.1297.3
ARG BUILDKITE_AGENT_VERSION=3.101.0

# Helper function to map architecture names
RUN set -e && \
  case "${TARGETARCH}" in \
    amd64) echo "x86_64" > /tmp/shellcheck_arch && echo "snyk-alpine" > /tmp/snyk_binary ;; \
    arm64) echo "aarch64" > /tmp/shellcheck_arch && echo "snyk-alpine-arm64" > /tmp/snyk_binary ;; \
    *) echo "Unsupported architecture: ${TARGETARCH}" >&2 && exit 1 ;; \
  esac

# Install OS packages
RUN apk add --no-cache \
  aws-cli \
  bash \
  ca-certificates \
  curl \
  docker \
  git \
  jq \
  make \
  ncurses \
  openssh \
  perl \
  xz \
  zip \
  gzip \
  && aws --version

# Install Terraform
RUN curl -Lsfo terraform.zip \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
  && unzip -q terraform.zip \
  && mv terraform /usr/local/bin/terraform \
  && rm -rf ./terraform.zip

# Install shellcheck
RUN shellcheck_arch=$(cat /tmp/shellcheck_arch) \
  && curl -Lsfo shellcheck.tar.xz \
  "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.${shellcheck_arch}.tar.xz" \
  && tar -xf shellcheck.tar.xz \
  && mv "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin/shellcheck \
  && rm -rf "./shellcheck-v${SHELLCHECK_VERSION}" ./shellcheck.tar.xz

# Install shfmt
RUN curl -Lsfo /usr/local/bin/shfmt \
  "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_${TARGETARCH}" \
  && chmod +x /usr/local/bin/shfmt

# Install yq
RUN curl -Lsfo /usr/local/bin/yq \
  "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" \
  && chmod +x /usr/local/bin/yq

# Install schma
RUN curl -Lsfo /usr/local/bin/schma \
  "https://github.com/seek-oss/schma/releases/download/v${SCHMA_VERSION}/schma-linux-${TARGETARCH}" \
  && chmod +x /usr/local/bin/schma

# Install Snyk
RUN snyk_binary=$(cat /tmp/snyk_binary) \
  && curl -Lsfo /usr/local/bin/snyk \
  "https://github.com/snyk/cli/releases/download/v${SNYK_VERSION}/${snyk_binary}" \
  && chmod +x /usr/local/bin/snyk

# Install the buildkite-agent
RUN curl -Lsfo buildkite-agent.tar.gz \
  "https://github.com/buildkite/agent/releases/download/v${BUILDKITE_AGENT_VERSION}/buildkite-agent-linux-${TARGETARCH}-${BUILDKITE_AGENT_VERSION}.tar.gz" \
  && tar -xf buildkite-agent.tar.gz \
  && mv buildkite-agent /usr/local/bin/buildkite-agent \
  && rm ./buildkite-agent.tar.gz ./buildkite-agent.cfg ./bootstrap.sh

# Install toolbox
ADD bin "${TOOLBOX_HOME}/bin"
ADD lib "${TOOLBOX_HOME}/lib"
RUN ln -s "${TOOLBOX_HOME}/bin/toolbox.sh" /usr/local/bin/toolbox
