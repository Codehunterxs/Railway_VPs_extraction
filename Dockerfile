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

# Install common utilities, SSH, socat for port forwarding
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openssh-server \
      wget \
      curl \
      git \
      nano \
      sudo \
      software-properties-common \
      socat \
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

# Configure SSH to use port 22 internally
RUN echo "Port 22" > /etc/ssh/sshd_config.d/custom.conf && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/custom.conf && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/custom.conf

# Optional hostname file
RUN echo "Dark" > /etc/hostname

# Force bash prompt
RUN echo 'export PS1="root@Dark:\\w# "' >> /root/.bashrc

# Railway will expose this port
EXPOSE 8080

# Create web interface that shows connection info
RUN echo '#!/usr/bin/env python3\n\
from http.server import BaseHTTPRequestHandler, HTTPServer\n\
import socket\n\
import os\n\
\n\
class InfoHandler(BaseHTTPRequestHandler):\n\
    def do_GET(self):\n\
        if self.path == "/" or self.path == "/health":\n\
            domain = os.environ.get("RAILWAY_PUBLIC_DOMAIN", "your-app.railway.app")\n\
            port = os.environ.get("PORT", "8080")\n\
            \n\
            # Check if SSH is running\n\
            ssh_status = "Running"\n\
            try:\n\
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\n\
                sock.settimeout(1)\n\
                result = sock.connect_ex(("127.0.0.1", 22))\n\
                sock.close()\n\
                if result != 0:\n\
                    ssh_status = "Not Running"\n\
            except:\n\
                ssh_status = "Error"\n\
            \n\
            self.send_response(200)\n\
            self.send_header("Content-type", "text/html")\n\
            self.end_headers()\n\
            html = f"""<!DOCTYPE html>\n\
<html>\n\
<head>\n\
    <title>SSH Server - Dark</title>\n\
    <style>\n\
        body {{ font-family: monospace; background: #1e1e1e; color: #00ff00; padding: 20px; }}\n\
        .container {{ max-width: 800px; margin: 0 auto; }}\n\
        h1 {{ color: #00ff00; }}\n\
        .status {{ padding: 10px; background: #2d2d2d; border-radius: 5px; margin: 10px 0; }}\n\
        .command {{ background: #000; padding: 15px; border-radius: 5px; margin: 10px 0; }}\n\
        .info {{ color: #ffff00; }}\n\
    </style>\n\
</head>\n\
<body>\n\
    <div class="container">\n\
        <h1>🖥️ SSH Server Status</h1>\n\
        <div class="status">\n\
            <strong>SSH Service:</strong> <span class="info">{ssh_status}</span><br>\n\
            <strong>Domain:</strong> <span class="info">{domain}</span><br>\n\
            <strong>Port:</strong> <span class="info">{port}</span>\n\
        </div>\n\
        \n\
        <h2>📡 Connect via SSH:</h2>\n\
        <div class="command">\n\
            ssh root@{domain} -p {port}\n\
        </div>\n\
        \n\
        <h2>ℹ️ Connection Info:</h2>\n\
        <div class="status">\n\
            <strong>Host:</strong> {domain}<br>\n\
            <strong>Port:</strong> {port}<br>\n\
            <strong>Username:</strong> root<br>\n\
            <strong>Password:</strong> [Set via ROOT_PASSWORD env variable]\n\
        </div>\n\
    </div>\n\
</body>\n\
</html>"""\n\
            self.wfile.write(html.encode())\n\
        else:\n\
            self.send_response(404)\n\
            self.end_headers()\n\
    \n\
    def log_message(self, format, *args):\n\
        pass\n\
\n\
if __name__ == "__main__":\n\
    port = int(os.environ.get("PORT", "8080"))\n\
    server = HTTPServer(("0.0.0.0", port), InfoHandler)\n\
    print(f"Web interface running on port {port}")\n\
    server.serve_forever()\n\
' > /web_server.py && chmod +x /web_server.py

# Create startup script that forwards Railway's port to SSH
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Get Railway assigned port (defaults to 8080)\n\
RAILWAY_PORT=${PORT:-8080}\n\
\n\
echo "========================================"\n\
echo "Railway Port: $RAILWAY_PORT"\n\
echo "SSH internal port: 22"\n\
echo "========================================"\n\
\n\
# Start SSH on port 22\n\
/usr/sbin/sshd\n\
\n\
echo "SSH server started on port 22"\n\
\n\
# Start web interface on Railway port for initial connection info\n\
python3 /web_server.py &\n\
\n\
# Give services time to start\n\
sleep 3\n\
\n\
# Forward Railway port to SSH (this is the key!)\n\
echo "Starting port forwarding: $RAILWAY_PORT -> 22"\n\
exec socat TCP-LISTEN:$RAILWAY_PORT,fork,reuseaddr TCP:127.0.0.1:22\n\
' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
