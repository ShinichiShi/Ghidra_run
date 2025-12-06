# Vestigo Features Extraction Pipeline

This repository contains a pipeline for extracting advanced features from firmware binaries using Ghidra. It is designed to process large batches of binaries and generate detailed JSON datasets suitable for machine learning tasks, such as Graph Neural Networks (GNNs).

## Features

-   **Batch Processing**: Efficiently handles large numbers of binaries.
-   **Automated Ghidra Analysis**: Uses Ghidra's headless analyzer to extract features.
-   **Rich Feature Set**:
    -   **Control Flow Graph (CFG)**: Basic blocks, edges, loop depth, dominance.
    -   **Instruction Level**: Opcode histograms, N-grams, P-code operations.
    -   **Entropy Metrics**: Function byte entropy, opcode entropy.
    -   **Crypto Signatures**: Detection of cryptographic constants (AES S-Box, SHA constants, etc.).
    -   **Labeling**: Automatic function labeling based on known names and detected signatures.

## Prerequisites

-   **OS**: Linux (Ubuntu, Debian, Fedora, RHEL, CentOS)
-   **Java**: JDK 17+ (Required for Ghidra)
-   **Python**: Python 3.8+
-   **Ghidra**: Version 11.0+ (Auto-installed by setup script)

## Installation

### Automated Setup (Recommended)

The `setup_ghidra.sh` script automates the entire setup process, including installing Java, Ghidra, and Python dependencies.

```bash
./setup_ghidra.sh
```

Follow the on-screen instructions. You may be prompted to download a binary archive manually if required.

### Manual Setup

1.  **Install Ghidra**: Download and extract Ghidra to a location of your choice (e.g., `/opt/ghidra`).
2.  **Set Environment Variable**:
    ```bash
    export GHIDRA_HOME=/path/to/ghidra
    ```
3.  **Install Python Dependencies**:
    ```bash
    pip install python-dotenv
    ```

## Usage

1.  **Prepare Binaries**: Place your target binaries (`.elf`, `.o`, `.a`, `.bin`) in the `builds_new/` directory.
2.  **Run Pipeline**:
    ```bash
    python3 run_batch_pipeline.py
    ```

The script will:
-   Auto-detect your Ghidra installation.
-   Scan `builds_new/` for binaries.
-   Process them in batches.
-   Output progress and summary statistics.

## Output

The extracted features are saved as JSON files in the `ghidra_json_new/` directory.

**File Naming**: `<binary_name>_features.json`

**JSON Structure**:
```json
{
    "binary": "example.elf",
    "metadata": { ... },
    "functions": [
        {
            "name": "AES_Encrypt",
            "address": "00101234",
            "label": "AES-128",  // <--- Auto-generated label
            "graph_level": { ... },
            "node_level": [ ... ],
            "edge_level": [ ... ],
            "crypto_signatures": {
                "has_aes_sbox": 1,
                ...
            },
            ...
        }
    ]
}
```

## Labeling Logic

Functions are labeled based on a priority system:
1.  **Name Mapping**: Known function names (e.g., `AES_Encrypt`) are mapped to specific labels.
2.  **Crypto Signatures**: If no name match, the function is checked for cryptographic constants (AES S-Boxes, SHA constants, RSA BigInt operations).
3.  **Default**: Labeled as "Unknown" if no matches found.
