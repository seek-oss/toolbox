FROM alpine:3.15.0

ARG TOOLBOX_VERSION
ENV TOOLBOX_VERSION="${TOOLBOX_VERSION}"
ENV TOOLBOX_HOME=/usr/local/share/toolbox

ARG GLIBC_VERSION=2.35-r0
ARG AWSCLI_VERSION=2.9.7
ARG TERRAFORM_VERSION=1.3.6
ARG SHELLCHECK_VERSION=0.9.0
ARG SHFMT_VERSION=3.6.0
ARG YQ_VERSION=4.30.5
ARG SCHMA_VERSION=0.0.1
ARG SNYK_VERSION=1.1071.0
ARG BUILDKITE_AGENT_VERSION=3.41.0

# Install OS packages
RUN apk add --no-cache \
  bash ca-certificates curl docker git jq make ncurses openssh perl xz zip gzip

# Install glibc compatibility for Alpine which is required to run AWS CLI V2. See comment here:
# https://github.com/aws/aws-cli/issues/4685#issuecomment-615872019
RUN curl -Lsfo /etc/apk/keys/sgerrand.rsa.pub \
  "https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub" \
  && curl -Lsfo glibc.apk \
  "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk" \
  && curl -sLo glibc-bin.apk \
  "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk" \
  && apk add --no-cache glibc.apk glibc-bin.apk \
  && rm ./glibc.apk ./glibc-bin.apk

# Install AWS CLI
RUN curl -Lsfo awscliv2.zip \
  "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" \
  && unzip -q awscliv2.zip \
  && ./aws/install \
  && aws --version \
  && rm -rf ./aws ./awscliv2.zip

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
