#!/bin/bash

IMAGE_NAME="earnings_scanner"
DOCKERFILE_PATH="."

# Function to display help message
show_help() {
    echo "Usage: ./run_docker.sh [options]"
    echo ""
    echo "This script builds and runs the Earnings Scanner Docker container."
    echo "It passes all provided options directly to the scanner_cli.py script inside the container."
    echo ""
    echo "Options:"
    echo "  --build            Force a rebuild of the Docker image before running."
    echo "  --finnhub-key YOUR_KEY Pass your Finnhub API key. Alternatively, set it in the Dockerfile or as an environment variable."
    echo "  All other options are passed directly to the scanner application."
    echo "  For scanner options, run: ./run_docker.sh --help (after first build)"
    echo ""
    echo "Example: ./run_docker.sh --date 07/26/2024 --workers 4 --use-finnhub"
    echo "         ./run_docker.sh --build --finnhub-key mysecretkey --analyze-ticker AAPL"
}

# --- Argument Parsing ---
REBUILD_IMAGE=false
DOCKER_RUN_ARGS=()
APP_ARGS=()
FINNHUB_API_KEY_ARG=""

# Separate Docker/script arguments from application arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --build)
            REBUILD_IMAGE=true
            shift # past argument
            ;;
        --finnhub-key)
            if [[ -n "$2" ]]; then
                FINNHUB_API_KEY_ARG="-e FINNHUB_API_KEY='$2'"
                shift # past argument
                shift # past value
            else
                echo "Error: --finnhub-key requires a value."
                exit 1
            fi
            ;;
        --help)
            # If '--help' is the only argument, or if image doesn't exist, show this script's help.
            # Otherwise, pass it to the application.
            if [[ $# -eq 1 ]] || ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
                show_help
                exit 0
            else
                APP_ARGS+=("$1")
                shift # past argument
            fi
            ;;
        *)
            APP_ARGS+=("$1") # Stash application argument
            shift # past argument
            ;;
    esac
done

# --- Docker Operations ---

# Check if image exists or if a rebuild is forced
if ! docker image inspect "$IMAGE_NAME" &> /dev/null || [[ "$REBUILD_IMAGE" == true ]]; then
    echo "Building Docker image: $IMAGE_NAME..."
    # When building, you might want to pass the FINNHUB_API_KEY as a build-arg
    # if you prefer not to hardcode it in the Dockerfile or pass it at runtime.
    # Example: docker build --build-arg FINNHUB_API_KEY_BUILD=${YOUR_KEY} -t "$IMAGE_NAME" "$DOCKERFILE_PATH"
    # For simplicity here, we assume it's in Dockerfile or passed at runtime.
    docker build -t "$IMAGE_NAME" "$DOCKERFILE_PATH"
    if [[ $? -ne 0 ]]; then
        echo "Docker build failed. Exiting."
        exit 1
    fi
else
    echo "Using existing Docker image: $IMAGE_NAME. Use --build to force a rebuild."
fi

# Run the Docker container
echo "Running Earnings Scanner in Docker..."
echo "Application arguments: ${APP_ARGS[@]}"
echo "Docker run arguments: ${FINNHUB_API_KEY_ARG}"

# Construct the docker run command
# We use -it for interactive terminal, --rm to remove container on exit.
# Mount current directory to /app in container if you need to access local files or output (optional).
# Example with volume mount:
# docker run -it --rm ${FINNHUB_API_KEY_ARG} -v "$(pwd)":/app/output_data "$IMAGE_NAME" "${APP_ARGS[@]}"
# For now, no volume mounts are included by default.

# Execute the command
# The eval is used here to correctly interpret the FINNHUB_API_KEY_ARG which might be empty
eval docker run -it --rm ${FINNHUB_API_KEY_ARG} "$IMAGE_NAME" "${APP_ARGS[@]}"

if [[ $? -ne 0 ]]; then
    echo "Docker run command failed."
    exit 1
fi

echo "Scanner execution finished." 