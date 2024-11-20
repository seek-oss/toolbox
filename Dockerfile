FROM alpine:3.20.3

ARG TOOLBOX_VERSION
ENV TOOLBOX_VERSION="${TOOLBOX_VERSION}"
ENV TOOLBOX_HOME=/usr/local/share/toolbox

ARG TERRAFORM_VERSION=1.9.8
ARG SHELLCHECK_VERSION=0.10.0
ARG SHFMT_VERSION=3.10.0
ARG YQ_VERSION=4.44.5
ARG SCHMA_VERSION=1.0.0
ARG SNYK_VERSION=1.1294.1
ARG BUILDKITE_AGENT_VERSION=3.87.0

# Install OS packages
RUN apk add --no-cache \
  aws-cli --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
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
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
  && unzip -q terraform.zip \
  && mv terraform /usr/local/bin/terraform \
  && rm -rf ./terraform.zip

# Install shellcheck
RUN curl -Lsfo shellcheck.tar.xz \
  "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" \
  && tar -xf shellcheck.tar.xz \
  && mv "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin/shellcheck \
  && rm -rf "./shellcheck-v${SHELLCHECK_VERSION}" ./shellcheck.tar.xz

# Install shfmt
RUN curl -Lsfo /usr/local/bin/shfmt \
  "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64" \
  && chmod +x /usr/local/bin/shfmt

# Install yq
RUN curl -Lsfo /usr/local/bin/yq \
  "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
  && chmod +x /usr/local/bin/yq

# Install schma
RUN curl -Lsfo /usr/local/bin/schma \
  "https://github.com/seek-oss/schma/releases/download/v${SCHMA_VERSION}/schma-linux-amd64" \
  && chmod +x /usr/local/bin/schma

# Install Snyk
RUN curl -Lsfo /usr/local/bin/snyk \
  "https://github.com/snyk/snyk/releases/download/v${SNYK_VERSION}/snyk-alpine" \
  && chmod +x /usr/local/bin/snyk

# Install the buildkite-agent
RUN curl -Lsfo buildkite-agent.tar.gz \
  "https://github.com/buildkite/agent/releases/download/v${BUILDKITE_AGENT_VERSION}/buildkite-agent-linux-amd64-${BUILDKITE_AGENT_VERSION}.tar.gz" \
  && tar -xf buildkite-agent.tar.gz \
  && mv buildkite-agent /usr/local/bin/buildkite-agent \
  && rm ./buildkite-agent.tar.gz ./buildkite-agent.cfg ./bootstrap.sh

# Install toolbox
ADD bin "${TOOLBOX_HOME}/bin"
ADD lib "${TOOLBOX_HOME}/lib"
RUN ln -s "${TOOLBOX_HOME}/bin/toolbox.sh" /usr/local/bin/toolbox
