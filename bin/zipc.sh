#!/bin/bash

# create_zip.sh - Create a zip file with unique name and directory exclusions
# Usage: create_zip.sh [options] <source_directory>
#   -o, --output <n>    Base name for zip file (default: source directory name)
#   -e, --exclude <pattern>    Directory or file pattern to exclude (can be used multiple times)
#   --no-git               Exclude .git directory
#   --no-binary            Exclude common non-ASCII/binary files (images, fonts, etc.)
#   --text-only            Shorthand for --no-git --no-binary
#   -h, --help             Show this help message

set -euo pipefail

# Default values
BASE_NAME=""
EXCLUDE_PATTERNS=()
SOURCE_DIR=""
SKIP_GIT=false
SKIP_BINARY=false

# Always exclude these patterns
DEFAULT_EXCLUDES=("node_modules")

# Always exclude these file patterns (binary/build artifacts)
DEFAULT_FILE_EXCLUDES=("*.class" "*.jar" "*.war" "*.ear" "*.o" "*.so" "*.dylib" "*.a" "*.dll" "*.exe" "*.pyc" "*.pyo" "*.zip" "*.tar" "*.gz" "*.bz2" "*.xz" "*.rar" "*.7z")

# Non-ASCII/binary file patterns (enabled with --no-binary or --text-only)
BINARY_FILE_EXCLUDES=("*.png" "*.jpg" "*.jpeg" "*.gif" "*.bmp" "*.ico" "*.svg" "*.webp" "*.tiff" "*.tif" "*.mp3" "*.mp4" "*.avi" "*.mov" "*.wmv" "*.flv" "*.wav" "*.ogg" "*.webm" "*.pdf" "*.doc" "*.docx" "*.xls" "*.xlsx" "*.ppt" "*.pptx" "*.ttf" "*.otf" "*.woff" "*.woff2" "*.eot" "*.db" "*.sqlite" "*.sqlite3" "*.bin" "*.dat" "*.enc" "*.p12" "*.pfx" "*.pem" "*.der" "*.DS_Store")

# Always exclude these Java project directories
DEFAULT_DIR_EXCLUDES=("target" "build" ".gradle" ".idea" ".settings" "bin" "out")

# Function to display usage
usage() {
    cat << EOF
Usage: $(basename "$0") [options] <source_directory>
       $(basename "$0") <source_directory> [options]

Options:
    -o, --output <n>         Base name for zip file (default: source directory name)
    -e, --exclude <pattern>     Directory or file pattern to exclude (can be used multiple times)
    --no-git                    Exclude .git directory
    --no-binary                 Exclude non-ASCII/binary files (images, fonts, media, etc.)
    --text-only                 Shorthand for --no-git --no-binary
    -h, --help                  Show this help message

Examples:
    $(basename "$0") -e node_modules -e .git .
        Creates: dirname_20251031_143022.zip
    
    $(basename "$0") . -e node_modules -e "*.zip" -e "*.log"
        Source directory can come first or last
    
    $(basename "$0") -e node_modules -e "*.zip" -e "*.log" .
        Excludes directories and file patterns (note the quotes around wildcards)
    
    $(basename "$0") -o backup -e .github -e "*.tmp" ~/myproject
        Creates: backup_20251031_143022.zip

    $(basename "$0") --text-only .
        Exclude .git and all binary/non-ASCII files

    $(basename "$0") --no-git --no-binary -e logs .
        Combine flags with additional excludes

Notes:
    - Quote wildcard patterns to prevent shell expansion: -e "*.zip"
    - Patterns can match files or directories
    - The script automatically handles the current directory (.) correctly
    - Source directory can be specified before or after options
    - Always excluded dirs: node_modules, target, build, .gradle, .idea, .settings, bin, out
    - Always excluded files: *.class, *.jar, *.war, *.ear, *.o, *.so, *.dylib, *.a, *.dll, *.exe,
      *.pyc, *.pyo, *.zip, *.tar, *.gz, *.bz2, *.xz, *.rar, *.7z
    - --no-binary adds: *.png, *.jpg, *.jpeg, *.gif, *.bmp, *.ico, *.svg, *.webp, *.tiff, *.tif,
      *.mp3, *.mp4, *.avi, *.mov, *.wmv, *.flv, *.wav, *.ogg, *.webm, *.pdf, *.doc, *.docx,
      *.xls, *.xlsx, *.ppt, *.pptx, *.ttf, *.otf, *.woff, *.woff2, *.eot, *.db, *.sqlite,
      *.sqlite3, *.bin, *.dat, *.enc, *.p12, *.pfx, *.pem, *.der, .DS_Store

The script will create a uniquely named zip file with a timestamp:
    <basename>_YYYYMMDD_HHMMSS.zip
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --output requires a value" >&2
                exit 1
            fi
            BASE_NAME="$2"
            shift 2
            ;;
        -e|--exclude)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --exclude requires a value" >&2
                exit 1
            fi
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        --no-git)
            SKIP_GIT=true
            shift
            ;;
        --no-binary)
            SKIP_BINARY=true
            shift
            ;;
        --text-only)
            SKIP_GIT=true
            SKIP_BINARY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
        *)
            if [[ -z "$SOURCE_DIR" ]]; then
                SOURCE_DIR="$1"
                shift
            else
                echo "Error: Multiple source directories specified" >&2
                echo "Hint: If using wildcards like *.zip, enclose them in quotes: -e \"*.zip\"" >&2
                exit 1
            fi
            ;;
    esac
done

# Validate source directory
if [[ -z "$SOURCE_DIR" ]]; then
    echo "Error: Source directory not specified" >&2
    echo "Use -h or --help for usage information" >&2
    exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR" >&2
    exit 1
fi

# Set BASE_NAME to basename of source directory if not specified
if [[ -z "$BASE_NAME" ]]; then
    # Get the absolute path first to handle "." correctly
    ABS_PATH=$(cd "$SOURCE_DIR" && pwd)
    BASE_NAME=$(basename "$ABS_PATH")
fi

# Generate unique filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ZIP_FILE="${BASE_NAME}_${TIMESTAMP}.zip"

# Add flag-based excludes
if [[ "$SKIP_GIT" == true ]]; then
    EXCLUDE_PATTERNS+=(".git")
fi
if [[ "$SKIP_BINARY" == true ]]; then
    for pattern in "${BINARY_FILE_EXCLUDES[@]}"; do
        EXCLUDE_PATTERNS+=("$pattern")
    done
fi

# Add default excludes to the patterns
for pattern in "${DEFAULT_EXCLUDES[@]}"; do
    EXCLUDE_PATTERNS+=("$pattern")
done
for pattern in "${DEFAULT_DIR_EXCLUDES[@]}"; do
    EXCLUDE_PATTERNS+=("$pattern")
done
for pattern in "${DEFAULT_FILE_EXCLUDES[@]}"; do
    EXCLUDE_PATTERNS+=("$pattern")
done

# Build exclude arguments for zip command
# macOS zip needs various pattern formats for comprehensive exclusion
EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]+"${EXCLUDE_PATTERNS[@]}"}"; do
    # Remove leading/trailing slashes from directory patterns
    clean_pattern="${pattern#/}"
    clean_pattern="${clean_pattern%/}"
    
    # Check if it's a wildcard pattern
    if [[ "$pattern" == *"*"* ]] || [[ "$pattern" == *"?"* ]]; then
        # File pattern - add as-is and with path variants
        EXCLUDE_ARGS+=(-x "$pattern" "*/$pattern" "**/$pattern")
    else
        # Directory pattern - add with /* suffix and path variants
        EXCLUDE_ARGS+=(-x "${clean_pattern}/*" "*/${clean_pattern}/*" "**/${clean_pattern}/*")
    fi
done

# Create the zip file
echo "Creating zip file: $ZIP_FILE"
echo "Source directory: $SOURCE_DIR"
if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
    echo "Excluding patterns: ${EXCLUDE_PATTERNS[*]}"
fi

cd "$(dirname "$SOURCE_DIR")"
SOURCE_BASE=$(basename "$SOURCE_DIR")

# Handle "." as source directory - stay in current directory and zip contents
if [[ "$SOURCE_DIR" == "." ]]; then
    # Already in the right directory, zip current directory contents
    SOURCE_BASE="."
elif [[ "$SOURCE_BASE" == "." ]]; then
    # Handle paths ending in "/."
    cd "$SOURCE_DIR"
    SOURCE_BASE="."
fi

# macOS zip is verbose by default, so we filter output to show only errors
if zip -r "$ZIP_FILE" "$SOURCE_BASE" ${EXCLUDE_ARGS[@]+"${EXCLUDE_ARGS[@]}"} 2>&1 | grep -v "adding:" | grep -v "^$" || [[ ${PIPESTATUS[0]} -eq 0 ]]; then
    # Get the full path of the created zip file
    FULL_PATH=$(realpath "$ZIP_FILE" 2>/dev/null || echo "$(pwd)/$ZIP_FILE")
    echo "Successfully created: $FULL_PATH"
    
    # Show file size
    SIZE=$(du -h "$ZIP_FILE" | cut -f1)
    echo "File size: $SIZE"
else
    echo "Error: Failed to create zip file" >&2
    exit 1
fi
