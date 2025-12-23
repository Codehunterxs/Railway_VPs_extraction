FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ARG ROOT_PASSWORD="Darkboy336"

# Install minimal tools and tzdata
RUN apt-get update && \
    apt-get install -y --no-install-recommends apt-utils ca-certificates gnupg2 curl wget lsb-release tzdata && \
    ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

# Install common utilities, SSH, and software-properties-common for add-apt-repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openssh-server \
      wget \
      curl \
      git \
      nano \
      sudo \
      software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends python3.12 python3.12-venv && \
    rm -rf /var/lib/apt/lists/*

# Make python3 point to python3.12
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# SSH root password
RUN echo "root:${ROOT_PASSWORD}" | chpasswd \
    && mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || true \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true

# Optional hostname file
RUN echo "Dark" > /etc/hostname

# Force bash prompt
RUN echo 'export PS1="root@Dark:\\w# "' >> /root/.bashrc

# Railway will automatically assign a PORT environment variable
EXPOSE 22

# Create a startup script for Railway
RUN echo '#!/bin/bash\n\
# Use Railway'\''s PORT environment variable, fallback to 22 if not set\n\
SSH_PORT=${PORT:-22}\n\
\n\
# Update SSH config to use the Railway port\n\
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config\n\
sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config\n\
echo "Port $SSH_PORT" >> /etc/ssh/sshd_config\n\
\n\
# Display connection info\n\
echo "========================================"\n\
echo "SSH Server starting on port: $SSH_PORT"\n\
echo "Root password: Set via ROOT_PASSWORD env"\n\
echo "========================================"\n\
\n\
# Start SSH daemon in foreground\n\
/usr/sbin/sshd -D -e' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
