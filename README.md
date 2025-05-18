# Anamorphic Desqueeze Tools

A collection of scripts and utilities for desqueezing 1.575x anamorphic footage while preserving original video characteristics.

## Overview

This repository contains tools for working with anamorphic footage, specifically with a squeeze factor of 1.575. The scripts help properly desqueeze footage for editing, preview, and delivery while maintaining original video quality (codec, bitrate, color profile).

## Features

- Precise 1.575x anamorphic desqueeze
- Preserves original video codec
- Maintains original bitrate 
- Preserves color information (colorspace, color transfer, primaries)
- Keeps all metadata intact
- Optional cropping modes:
  - Cinema crop (to specific aspect ratio like 2.39:1)
  - Edge crop (automatically crops to eliminate black bars on 16:9 displays)
- High-quality Lanczos scaling

## Requirements

- FFmpeg (latest version recommended)
- Python 3.6+
- Git
- bc and awk for shell script

## Quick Start

### Basic Desqueeze

```bash
./scripts/desqueeze.sh input.mp4 output.mp4 1.575
```

### Desqueeze and Crop to Cinema 2.39:1

```bash
./scripts/desqueeze.sh input.mp4 output.mp4 1.575 --crop-mode cinema --target-ratio 2.39
```

### Desqueeze and Auto-Crop Edges

```bash
./scripts/desqueeze.sh input.mp4 output.mp4 1.575 --crop-mode edges
```

### Batch Processing

```bash
# Process all videos in a folder
python3 scripts/batch_process.py input_folder/ output_folder/

# With cropping options
python3 scripts/batch_process.py input_folder/ output_folder/ --crop-mode cinema --target-ratio 2.39
```

## Scripts

- `desqueeze.sh` - Shell script for desqueezing individual files with full quality preservation
- `batch_process.py` - Process multiple files while preserving original video characteristics
- More scripts coming soon!

## License

MIT

## Contact

Your Name
