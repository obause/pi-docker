FROM agent0ai/agent-zero:v2.10

# PyTorch 2.4.0's aarch64 wheel uses LSE instructions that the
# Raspberry Pi 4's Cortex-A72 does not support. 2.4.1 contains the fix.
RUN /opt/venv-a0/bin/pip install \
        --no-cache-dir \
        --no-deps \
        --force-reinstall \
        "torch==2.4.1" \
    && /opt/venv-a0/bin/python -c \
        "import torch; assert torch.__version__.startswith('2.4.1')"
