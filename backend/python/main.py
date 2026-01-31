#!/usr/bin/env python3
"""Entry point for NeuronAI Python service."""

import asyncio
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from neuronai.grpc.server import serve

if __name__ == "__main__":
    asyncio.run(serve())
