FROM python:3.11-slim

# Set environment variables for non-interactive frontend
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV FINNHUB_API_KEY YOUR_FINNHUB_API_KEY_HERE

# Install system dependencies required for Chrome and ChromeDriver
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    unzip \
    # Dependencies for Chrome
    libglib2.0-0 \
    libnss3 \
    libgconf-2-4 \
    libfontconfig1 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    libasound2 \
    # Dependencies for webdriver_manager (indirectly for Chrome)
    ca-certificates \
    fonts-liberation \
    lsb-release \
    xdg-utils \
    # Add gnupg if not already present for apt-key, though it was in the previous list
    gnupg \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Install Google Chrome (for amd64) or Chromium (for arm64)
RUN apt-get update && \
    ARCH=$(dpkg --print-architecture) && \
    echo "Detected architecture: $ARCH" && \
    if [ "$ARCH" = "amd64" ]; then \
        echo "Installing Google Chrome version 114 for amd64" && \
        CHROME_VERSION="114.0.5735.198-1" && \
        wget -q "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb" -O google-chrome-stable.deb && \
        apt-get install -y ./google-chrome-stable.deb --no-install-recommends && \
        rm google-chrome-stable.deb && \
        # Ensure the google-chrome.list doesn't interfere if it was added by a previous layer or if apt install .deb adds it.
        # Or, ensure it's correctly configured if needed for dependencies, though direct .deb install should handle them.
        # For simplicity, we'll assume the .deb contains all needed direct dependencies or apt will resolve them.
        # If issues arise, we might need to add the repo first, then install a specific version via apt-get install google-chrome-stable=<version>.
        # However, direct .deb download and install is often more reliable for specific old versions.
        echo "Installed Google Chrome version ${CHROME_VERSION}" ; \
    elif [ "$ARCH" = "arm64" ]; then \
        # For arm64, webdriver-manager might download a different chromedriver.
        # If chromedriver 114 is still attempted on arm64, Chromium 114 would be needed.
        # Pinning Chromium on arm64 via apt is trickier as versions depend on distro feeds.
        # For now, focusing on amd64 as per logs. If arm64 is the actual target and fails, this part may need adjustment.
        echo "Installing latest available Chromium for arm64 (potential mismatch if chromedriver 114 is used)" && \
        apt-get install -y chromium --no-install-recommends; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# Set up the working directory
WORKDIR /app

# Copy requirements.txt and install Python dependencies
COPY cli_scanner/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Make cli_scanner/run.sh executable
RUN chmod +x /app/cli_scanner/run.sh

# WORKDIR remains /app for general context
WORKDIR /app

# Entrypoint will cd into cli_scanner and then execute run.sh.
# Arguments passed to `docker run` will be passed to this script.
ENTRYPOINT ["sh", "-c", "cd /app/cli_scanner && ./run.sh \"$@\"", "--"]

# Default command is empty as cli_scanner/run.sh handles default behavior.
CMD [] 