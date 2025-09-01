#!/bin/bash
# Add public keys to authorized_keys
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p /root/.ssh
    echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

# Set up zsh as default shell for SSH sessions
if [ -n "$USE_ZSH" ] && [ "$USE_ZSH" = "true" ]; then
    # Method 1: Change the default shell (might not persist)
    chsh -s /bin/zsh root
    
    # Method 2: Add auto-switch to bashrc (more reliable)
    echo '
# Auto-switch to zsh for interactive SSH sessions
if [[ $- == *i* ]] && [ -x "$(command -v zsh)" ] && [ -z "$ZSH_VERSION" ]; then
    export SHELL=/bin/zsh
    exec zsh -l
fi' >> /root/.bashrc
    
    # Method 3: Force zsh in SSH config
    echo "ForceCommand exec /bin/zsh -l" >> /etc/ssh/sshd_config.d/zsh.conf
fi

# Login to huggingface
if [ -f .venv/bin/activate ]; then
    source .venv/bin/activate
    python -c "from huggingface_hub.hf_api import HfFolder; import os; HfFolder.save_token(os.environ['HF_TOKEN'])"
fi

# Generate SSH host keys
ssh-keygen -A

# Start SSH service
service ssh start

# Print sshd logs to stdout
tail -f /var/log/auth.log &

# Start a simple server that serves the content of main.log on port 10101
touch main.log
python -c '
import http.server
import socketserver
class LogHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        with open("main.log", "rb") as f:
            self.wfile.write(f.read())
with socketserver.TCPServer(("", 10101), LogHandler) as httpd:
    httpd.serve_forever()
' &

# Keep the container running
exec tail -f /dev/null