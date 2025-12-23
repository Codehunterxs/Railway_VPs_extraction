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
      netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev && \
    rm -rf /var/lib/apt/lists/*

# Make python3 point to python3.12
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# SSH root password
RUN echo "root:${ROOT_PASSWORD}" | chpasswd \
    && mkdir -p /var/run/sshd

# Configure SSH to use port 2222
RUN echo "Port 2222" > /etc/ssh/sshd_config.d/custom.conf && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/custom.conf && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/custom.conf

# Optional hostname file
RUN echo "Dark" > /etc/hostname

# Force bash prompt
RUN echo 'export PS1="root@Dark:\\w# "' >> /root/.bashrc

# Expose both HTTP and SSH ports
EXPOSE 8080 2222

# Create a simple HTTP health check server using correct imports
RUN echo '#!/usr/bin/env python3\n\
from http.server import BaseHTTPRequestHandler, HTTPServer\n\
import socket\n\
\n\
class HealthCheckHandler(BaseHTTPRequestHandler):\n\
    def do_GET(self):\n\
        if self.path == "/" or self.path == "/health":\n\
            try:\n\
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\n\
                sock.settimeout(2)\n\
                result = sock.connect_ex(("127.0.0.1", 2222))\n\
                sock.close()\n\
                if result == 0:\n\
                    self.send_response(200)\n\
                    self.send_header("Content-type", "text/html")\n\
                    self.end_headers()\n\
                    self.wfile.write(b"<html><body>")\n\
                    self.wfile.write(b"<h1>SSH Server is Running</h1>")\n\
                    self.wfile.write(b"<p>Connect via SSH:</p>")\n\
                    self.wfile.write(b"<pre>ssh root@YOUR_DOMAIN -p 2222</pre>")\n\
                    self.wfile.write(b"<p>SSH is listening on port 2222</p>")\n\
                    self.wfile.write(b"</body></html>")\n\
                else:\n\
                    self.send_response(503)\n\
                    self.send_header("Content-type", "text/plain")\n\
                    self.end_headers()\n\
                    self.wfile.write(b"SSH service not available")\n\
            except Exception as e:\n\
                self.send_response(500)\n\
                self.send_header("Content-type", "text/plain")\n\
                self.end_headers()\n\
                self.wfile.write(f"Error: {str(e)}".encode())\n\
        else:\n\
            self.send_response(404)\n\
            self.end_headers()\n\
    \n\
    def log_message(self, format, *args):\n\
        pass\n\
\n\
if __name__ == "__main__":\n\
    server = HTTPServer(("0.0.0.0", 8080), HealthCheckHandler)\n\
    print("Health check server running on port 8080")\n\
    server.serve_forever()\n\
' > /health_server.py && chmod +x /health_server.py

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Kill any existing processes on ports\n\
fuser -k 8080/tcp 2>/dev/null || true\n\
fuser -k 2222/tcp 2>/dev/null || true\n\
sleep 2\n\
\n\
echo "========================================"\n\
echo "HTTP Health Check: Port 8080"\n\
echo "SSH Server: Port 2222"\n\
echo "========================================"\n\
echo "To connect: ssh root@YOUR_RAILWAY_DOMAIN -p 2222"\n\
echo "========================================"\n\
\n\
# Start HTTP health check server in background\n\
python3 /health_server.py &\n\
\n\
# Wait a moment for health server to start\n\
sleep 2\n\
\n\
# Start SSH daemon in foreground\n\
exec /usr/sbin/sshd -D -e\n\
' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
