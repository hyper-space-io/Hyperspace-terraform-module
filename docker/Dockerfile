FROM hashicorp/tfc-agent:latest

USER root

# Install sudo. The container runs as a non-root user, but people may rely on
# the ability to apt-get install things.
RUN apt-get -y install sudo

# Permit tfc-agent to use sudo apt-get commands.
RUN echo 'tfc-agent ALL=NOPASSWD: /usr/bin/apt-get , /usr/bin/apt' >> /etc/sudoers.d/50-tfc-agent

USER tfc-agent


# Install AWS CLI
RUN apt-get update && apt-get install -y unzip curl && \
    curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o awscliv2.zip && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

ENV PATH=$PATH:/usr/local/bin

# /bin/tfc-agent is the entrypoint from the hashicorp image,
ENTRYPOINT ["/bin/tfc-agent"]