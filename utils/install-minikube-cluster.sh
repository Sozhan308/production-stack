#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_TYPE=${1:-"minimal"}  # Default to minimal install

minikube_exists() {
  command -v minikube >/dev/null 2>&1
}

install_minikube() {
  if ! minikube_exists; then
    curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
  fi
}

start_minimal() {
  minikube start --driver docker
}

start_with_gpu() {
  echo "net.core.bpf_jit_harden=0" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker
  sudo minikube start --driver docker --container-runtime docker --gpus all --force --addons=nvidia-device-plugin
}

install_gpu_components() {
  sudo helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && sudo helm repo update
  sudo helm install --wait --generate-name \
    -n gpu-operator --create-namespace \
    nvidia/gpu-operator \
    --version=v24.9.1
}

# Install base components
bash "$SCRIPT_DIR/install-kubectl.sh"

# Install additional components based on type
case $INSTALL_TYPE in
  "full")
    bash "$SCRIPT_DIR/install-helm.sh"
    install_minikube
    start_with_gpu
    install_gpu_components
    ;;
  "minimal"|*)
    install_minikube
    start_minimal
    ;;
esac
