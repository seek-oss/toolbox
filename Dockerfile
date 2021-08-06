FROM alpine:3.14.0

ARG TOOLBOX_VERSION
ENV TOOLBOX_VERSION="${TOOLBOX_VERSION}"
ENV TOOLBOX_HOME=/usr/local/share/toolbox

ARG GLIBC_VERSION=2.33-r0
ARG AWSCLI_VERSION=2.2.21
ARG TERRAFORM_VERSION=1.0.3
ARG SHELLCHECK_VERSION=0.7.2
ARG SHFMT_VERSION=3.3.0
ARG YQ_VERSION=4.9.3
ARG SCHMA_VERSION=0.0.1
ARG SNYK_VERSION=1.621.0
ARG TERMINAL_TO_HTML_VERSION=3.6.1
ARG BUILDKITE_AGENT_VERSION=3.32.0

# Install OS packages.
RUN apk add --no-cache \
    bash ca-certificates curl git jq make ncurses openssh perl xz zip gzip

# Install glibc compatibility for Alpine which is required to run AWS CLI V2. See comment here:
# https://github.com/aws/aws-cli/issues/4685#issuecomment-615872019
RUN curl -Lso /etc/apk/keys/sgerrand.rsa.pub \
    "https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub" && \
    curl -Lso glibc.apk \
    "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk" && \
    curl -sLo glibc-bin.apk \
    "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk" && \
    apk add --no-cache glibc.apk glibc-bin.apk

# Install AWS CLI
RUN curl -Lso awscliv2.zip \
  "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" \
  && unzip -q awscliv2.zip \
  && ./aws/install

# Install Terraform
RUN curl -Lso terraform.zip \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
  && unzip -q terraform.zip \
  && mv terraform /usr/local/bin/terraform

# Install shellcheck
RUN curl -Lso shellcheck.tar.xz \
  "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" \
  && tar -xf shellcheck.tar.xz \
  && mv "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin/shellcheck

# Install shfmt
RUN curl -Lso /usr/local/bin/shfmt \
  "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64" \
  && chmod +x /usr/local/bin/shfmt

# Install yq
RUN curl -Lso /usr/local/bin/yq \
  "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
  && chmod +x /usr/local/bin/yq

# Install schma
RUN curl -Lso /usr/local/bin/schma \
  "https://github.com/seek-oss/schma/releases/download/v${SCHMA_VERSION}/schma-linux-amd64" \
  && chmod +x /usr/local/bin/schma

# Install Snyk
RUN curl -Lso /usr/local/bin/snyk \
  "https://github.com/snyk/snyk/releases/download/v${SNYK_VERSION}/snyk-alpine" \
  && chmod +x /usr/local/bin/snyk

# Install terminal-to-html
RUN curl -Lso terminal-to-html.gz \
  https://github.com/buildkite/terminal-to-html/releases/download/v${TERMINAL_TO_HTML_VERSION}/terminal-to-html-${TERMINAL_TO_HTML_VERSION}-linux-amd64.gz \
  && gunzip terminal-to-html.gz \
  && mv terminal-to-html /usr/local/bin/terminal-to-html \
  && chmod +x /usr/local/bin/terminal-to-html

# Install the buildkite-agent
RUN curl -Lso buildkite-agent.tar.gz \
  https://github.com/buildkite/agent/releases/download/v${BUILDKITE_AGENT_VERSION}/buildkite-agent-linux-amd64-${BUILDKITE_AGENT_VERSION}.tar.gz \
  && tar -xvf buildkite-agent.tar.gz \
  && mv buildkite-agent /usr/local/bin/buildkite-agent

# Install toolbox
ADD bin "${TOOLBOX_HOME}/bin"
ADD lib "${TOOLBOX_HOME}/lib"
RUN ln -s "${TOOLBOX_HOME}/bin/toolbox.sh" /usr/local/bin/toolbox
