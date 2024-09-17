#!/bin/bash
echo "Hello! Starting conda installation..."
wget https://repo.anaconda.com/archive/Anaconda3-2024.06-1-Linux-x86_64.sh -O ~/anaconda3.sh
echo "Anaconda3 downloaded!"
bash ~/anaconda3.sh -b -p /home/ubuntu/anaconda3
echo "Anaconda3 installed!"
eval "$(/home/ubuntu/anaconda3/bin/conda shell.bash hook)"
jupyter lab --NotebookApp.token="$JUPYTER_TOKEN" --allow-root --no-browser