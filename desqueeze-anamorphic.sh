#!/bin/bash

# desqueeze.sh - Desqueeze anamorphic footage with FFmpeg
# Usage: ./desqueeze.sh input_file output_file squeeze_ratio [options]

# Default values
CROP_MODE="none"
TARGET_RATIO=""

# Parse command line arguments
usage() {
  echo "Usage: $0 input_file output_file squeeze_ratio [options]"
  echo "Options:"
  echo "  --crop-mode MODE    Crop mode: none, cinema, edges (default: none)"
  echo "  --target-ratio R    Target aspect ratio (e.g., 2.39) for cinema crop"
  echo
  echo "Examples:"
  echo "  $0 input.mp4 output.mp4 1.575"
  echo "  $0 input.mp4 output.mp4 1.575 --crop-mode cinema --target-ratio 2.39"
  echo "  $0 input.mp4 output.mp4 1.575 --crop-mode edges"
  exit 1
}

# Parse arguments
if [ $# -lt 3 ]; then
  usage
fi

INPUT_FILE=$1
OUTPUT_FILE=$2
SQUEEZE_RATIO=$3
shift 3

# Process optional parameters
while [ $# -gt 0 ]; do
  case "$1" in
    --crop-mode)
      CROP_MODE="$2"
      shift 2
      ;;
    --target-ratio)
      TARGET_RATIO="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate the input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' not found."
  exit 1
fi

# Validate crop mode
if [ "$CROP_MODE" != "none" ] && [ "$CROP_MODE" != "cinema" ] && [ "$CROP_MODE" != "edges" ]; then
  echo "Error: Invalid crop mode. Must be 'none', 'cinema', or 'edges'."
  exit 1
fi

# Check if target ratio is needed
if [ "$CROP_MODE" = "cinema" ] && [ -z "$TARGET_RATIO" ]; then
  echo "Error: --target-ratio is required when using --crop-mode cinema"
  exit 1
fi

# Get video info
echo "Analyzing video file..."
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
BITRATE=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
COLORSPACE=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_space -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
COLOR_TRANSFER=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
COLOR_PRIMARIES=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_primaries -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")

if [ -z "$WIDTH" ] || [ -z "$HEIGHT" ]; then
  echo "Error: Could not detect video dimensions."
  exit 1
fi

echo "Original dimensions: ${WIDTH}x${HEIGHT}"
echo "Codec: $CODEC"
[ ! -z "$BITRATE" ] && echo "Bitrate: $BITRATE bps"
[ ! -z "$COLORSPACE" ] && echo "Colorspace: $COLORSPACE"
[ ! -z "$COLOR_TRANSFER" ] && echo "Color Transfer: $COLOR_TRANSFER"
[ ! -z "$COLOR_PRIMARIES" ] && echo "Color Primaries: $COLOR_PRIMARIES"

# Calculate new width based on squeeze ratio
NEW_WIDTH=$(echo "$WIDTH * $SQUEEZE_RATIO" | bc | awk '{print int($1)}')
echo "New dimensions after desqueeze: ${NEW_WIDTH}x${HEIGHT}"

# Prepare FFmpeg filter chain
FILTER_CHAIN="scale=${NEW_WIDTH}:${HEIGHT}:flags=lanczos"

# Handle cropping if requested
if [ "$CROP_MODE" = "cinema" ]; then
  # Calculate crop parameters for target aspect ratio
  CROP_HEIGHT=$(echo "$NEW_WIDTH / $TARGET_RATIO" | bc | awk '{print int($1)}')
  if [ "$CROP_HEIGHT" -lt "$HEIGHT" ]; then
    # Need to crop vertically
    CROP_Y=$(echo "($HEIGHT - $CROP_HEIGHT) / 2" | bc | awk '{print int($1)}')
    FILTER_CHAIN="${FILTER_CHAIN},crop=${NEW_WIDTH}:${CROP_HEIGHT}:0:${CROP_Y}"
    echo "Cropping to ${TARGET_RATIO}:1 aspect ratio: ${NEW_WIDTH}x${CROP_HEIGHT}"
  else
    echo "Warning: Cannot crop to ${TARGET_RATIO}:1 aspect ratio without reducing width"
  fi
elif [ "$CROP_MODE" = "edges" ]; then
  # Calculate new aspect ratio
  NEW_RATIO=$(echo "$SQUEEZE_RATIO * $WIDTH / $HEIGHT" | bc -l)
  # Calculate crop to eliminate black bars on 16:9 display
  TARGET_RATIO_169=1.7777777777
  if (( $(echo "$NEW_RATIO > $TARGET_RATIO_169" | bc -l) )); then
    # Crop height to match 16:9
    CROP_HEIGHT=$(echo "$NEW_WIDTH / $TARGET_RATIO_169" | bc | awk '{print int($1)}')
    if [ "$CROP_HEIGHT" -lt "$HEIGHT" ]; then
      CROP_Y=$(echo "($HEIGHT - $CROP_HEIGHT) / 2" | bc | awk '{print int($1)}')
      FILTER_CHAIN="${FILTER_CHAIN},crop=${NEW_WIDTH}:${CROP_HEIGHT}:0:${CROP_Y}"
      echo "Cropping to fit 16:9 display: ${NEW_WIDTH}x${CROP_HEIGHT}"
    fi
  else
    # Crop width to match 16:9
    CROP_WIDTH=$(echo "$HEIGHT * $TARGET_RATIO_169" | bc | awk '{print int($1)}')
    if [ "$CROP_WIDTH" -lt "$NEW_WIDTH" ]; then
      CROP_X=$(echo "($NEW_WIDTH - $CROP_WIDTH) / 2" | bc | awk '{print int($1)}')
      FILTER_CHAIN="${FILTER_CHAIN},crop=${CROP_WIDTH}:${HEIGHT}:${CROP_X}:0"
      echo "Cropping to fit 16:9 display: ${CROP_WIDTH}x${HEIGHT}"
    fi
  fi
fi

# Preserve original codec and settings as much as possible
EXTRA_ARGS=""

# Preserve bitrate if available
if [ ! -z "$BITRATE" ] && [ "$BITRATE" != "N/A" ]; then
  EXTRA_ARGS="$EXTRA_ARGS -b:v $BITRATE"
fi

# Preserve color information
if [ ! -z "$COLORSPACE" ] && [ "$COLORSPACE" != "N/A" ]; then
  EXTRA_ARGS="$EXTRA_ARGS -colorspace $COLORSPACE"
fi
if [ ! -z "$COLOR_TRANSFER" ] && [ "$COLOR_TRANSFER" != "N/A" ]; then
  EXTRA_ARGS="$EXTRA_ARGS -color_trc $COLOR_TRANSFER"
fi
if [ ! -z "$COLOR_PRIMARIES" ] && [ "$COLOR_PRIMARIES" != "N/A" ]; then
  EXTRA_ARGS="$EXTRA_ARGS -color_primaries $COLOR_PRIMARIES"
fi

# Perform the desqueeze
echo "Desqueezing with ratio $SQUEEZE_RATIO..."
echo "FFmpeg filter chain: $FILTER_CHAIN"
echo "FFmpeg extra arguments: $EXTRA_ARGS"

ffmpeg -i "$INPUT_FILE" -vf "$FILTER_CHAIN" \
  -c:v $CODEC $EXTRA_ARGS \
  -c:a copy \
  -map_metadata 0 \
  "$OUTPUT_FILE"

echo "Desqueeze complete: $OUTPUT_FILE"
echo "Original: ${WIDTH}x${HEIGHT}"
echo "Processed: Based on selected options"
