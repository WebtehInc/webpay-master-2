FROM ubuntu:20.04

# RVM version to install
ARG RVM_VERSION=stable
ENV RVM_VERSION=${RVM_VERSION}

# RMV user to create
ENV RVM_USER=webpay
ENV DEBIAN_FRONTEND=noninteractive
# Install RVM dependencies
RUN sed -i 's/^mesg n/tty -s \&\& mesg n/g' ~/.profile \
    && apt-get update -qq \
    && apt-get install -qy --no-install-recommends \
    # rvm depenencies
    ca-certificates curl git \
    # packages required by gems
    libpq-dev \
    # dev tools
    postgresql-client-12 zsh less \
    # packages required by app
    sudo > /dev/null \
    && rm -rf /var/lib/apt/lists/* && apt-get clean

# download rvm installer
RUN curl --silent --show-error --location https://raw.githubusercontent.com/rvm/rvm/${RVM_VERSION}/binscripts/rvm-installer -o rvm-installer \
    && curl --silent --show-error --location https://raw.githubusercontent.com/rvm/rvm/${RVM_VERSION}/binscripts/rvm-installer.asc -o rvm-installer.asc \
    && bash rvm-installer \
    && rm rvm-installer \
    && echo "rvm_autoupdate_flag=2" >> /etc/rvmrc \
    && echo "rvm_silence_path_mismatch_check_flag=1" >> /etc/rvmrc \
    && echo "install: --no-document" > /etc/gemrc \
    && useradd -m --no-log-init -r -g rvm ${RVM_USER} -u 1000

# Switch to a bash login shell to allow simple 'rvm' in RUN commands
SHELL ["/bin/bash", "-l", "-c"]

# Optional: child images can set Ruby versions to install (whitespace-separated)
ENV RVM_RUBY_VERSIONS "2.6.8"

# Optional: child images can set default Ruby version (default is first version)
ENV RVM_RUBY_DEFAULT 2.6.8

# install requested ruby versions
RUN if [ ! -z "${RVM_RUBY_VERSIONS}" ]; then \
    for v in $( echo ${RVM_RUBY_VERSIONS} | sed -E 's/[[:space:]]+/\n/g' ); do \
    echo "== docker-rvm: Installing ${v} ==" \
    && rvm install ${v}; \
    done \
    && echo "== docker-rvm: Setting default ${RVM_RUBY_DEFAULT} ==" \
    && rvm use --default ${RVM_RUBY_DEFAULT:-${RVM_RUBY_VERSIONS/[[:space:]]*/}} \
    && rvm cleanup all \
    && rm -rf /var/lib/apt/lists/*; \
    fi

CMD ["/bin/bash", "-l"]

RUN adduser ${RVM_USER} sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN mkdir -p /workbench/${RVM_USER}

WORKDIR /workbench/${RVM_USER}

RUN chown -R ${RVM_USER} .

USER ${RVM_USER}

ENV USER=${RVM_USER}

COPY Gemfile* /workbench/${RVM_USER}/

RUN gem install bundler && bundle install

COPY . /workbench/${RVM_USER}/

RUN sudo chown -R ${RVM_USER} .
