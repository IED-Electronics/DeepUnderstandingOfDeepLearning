#!/bin/bash
echo "Hello! Starting conda installation..."
wget https://repo.anaconda.com/archive/Anaconda3-2024.06-1-Linux-x86_64.sh -O ~/anaconda3.sh
echo "Anaconda3 downloaded!"
bash ~/anaconda3.sh -b -p /home/ubuntu/anaconda3
echo "Anaconda3 installed!"

# Add conda initialization to /etc/bash.bashrc for all users
echo 'eval "$(/home/ubuntu/anaconda3/bin/conda shell.bash hook)"' | sudo tee -a /etc/bash.bashrc

# Create systemd service for Jupyter Lab
sudo bash -c 'cat <<EOF > /etc/systemd/system/jupyterlab.service
[Unit]
Description=Jupyter Lab
After=network.target

[Service]
Type=simple
ExecStart=/home/ubuntu/anaconda3/bin/jupyter lab --NotebookApp.token="\$JUPYTER_TOKEN" --allow-root --no-browser
User=root
WorkingDirectory=/root
Environment="JUPYTER_TOKEN=your_token_here"
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd and enable the Jupyter Lab service
sudo systemctl daemon-reload
sudo systemctl enable jupyterlab.service
sudo systemctl start jupyterlab.service