# 🐳 Docker Cleaner Scripts

Interactive Docker resource cleanup scripts with beautiful UI for macOS systems. These scripts help you safely clean up unused Docker resources including dangling images, stopped containers, unused volumes, and build cache.

## 📁 Files Available

| Script | Language | File | Purpose |
|--------|----------|------|---------|
| 🇩🇪 German | German | `docker-cleaner.sh` | German version of the interactive Docker cleaner |
| 🇬🇧 English | English | `docker-cleaner-en.sh` | English version of the interactive Docker cleaner |

## 🚀 Quick Start

### Prerequisites
- **macOS** (designed for macOS Terminal)
- **Docker Desktop** installed and running
- **bash** shell

### Basic Usage

```bash
# Make scripts executable (first time only)
chmod +x docker-cleaner.sh
chmod +x docker-cleaner-en.sh

# Run German version
./docker-cleaner.sh

# Run English version
./docker-cleaner-en.sh

# Run with test mode (no actual deletions)
./docker-cleaner.sh --test
./docker-cleaner-en.sh --test

# Show help
./docker-cleaner.sh --help
./docker-cleaner-en.sh --help
```

## 🎯 Main Features

### 🗑️ Dangling Images Cleanup (Primary Feature)
Removes Docker images with `<none>` repository and tag names that are created during build processes.

```bash
# Example: Find and remove dangling images
./docker-cleaner.sh
# Select option [1] - Delete dangling images
```

### 🐳 Container Cleanup
Removes stopped/unused containers to free up system resources.

### 💾 Volume Cleanup
Safely removes unused volumes (with warnings about potential data loss).

### 🔨 Build Cache Cleanup
Clears Docker build cache to reclaim significant disk space.

### 📊 Detailed Analysis
Shows comprehensive Docker system statistics and resource usage.

### 🧪 Test Mode
Preview what would be deleted without actually removing anything.

## 🎨 User Interface

### Beautiful Terminal UI
- **Colored ASCII menus** with Unicode box-drawing characters
- **Emoji indicators** for different operations and states
- **Interactive dialogs** with confirmation prompts
- **Progress indicators** and status messages
- **Modern color scheme** optimized for macOS Terminal

### Main Menu Structure
```
╔════════════════════════════════════════════════════════════════════════╗
║                    🐳 DOCKER CLEANER v1.0.0                            ║
║              Interactive Resource Cleanup                           ║
╚════════════════════════════════════════════════════════════════════════╝

Status: 🟢 Running | Storage: 6GB

┌─────────────────────────────────────────────────────────────┐
│  🧹 Docker Resource Cleaner - Main Menu                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [1] 🗑️  Delete dangling images (<none> images)             │
│  [2] 🐳  Cleanup unused containers                          │
│  [3] 💾  Cleanup unused volumes                             │
│  [4] 🔨  Clear build cache                                    │
│  [5] 📊  Show detailed analysis                             │
│  [6] 🚀  Full cleanup (all above)                           │
│  [7] ⚙️  Advanced options                                    │
│                                                             │
│  [0] 🚪  Exit                                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🛡️ Safety Features

### ⚠️ Confirmation Dialogs
Every destructive operation requires explicit confirmation with clear warnings about potential consequences.

### 🧪 Test Mode
Run scripts in test mode to see what would be deleted without actually removing anything:

```bash
./docker-cleaner.sh --test
```

### 📋 Previews Before Deletion
All operations show detailed previews of what will be deleted, including:
- **List of affected resources**
- **Amount of disk space to be reclaimed**
- **Number of items to be removed**

### 🔒 Volume Safety
Special warnings for volume deletions due to potential data loss:
```
⚠️  Found: 3 unused volumes
WARNING: Deleting volumes can cause data loss!
```

## 📋 Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--help`, `-h` | Show help information | `./docker-cleaner.sh --help` |
| `--test` | Activate test mode (no deletions) | `./docker-cleaner.sh --test` |
| `--version` | Show script version | `./docker-cleaner.sh --version` |

## 🔧 Technical Details

### System Requirements
- **Operating System**: macOS (tested on macOS Monterey and later)
- **Docker**: Docker Desktop for Mac
- **Shell**: bash 3.2+ (default macOS bash)
- **Terminal**: Supports ANSI colors and Unicode characters

### Docker Commands Used
- `docker images --filter "dangling=true"`
- `docker ps -a --filter "status=exited"`
- `docker volume ls --filter "dangling=true"`
- `docker system df`
- `docker rmi`, `docker rm`, `docker volume prune`
- `docker builder prune --all --force`

### Script Architecture
```bash
docker-cleaner.sh
├── UI/Helper Functions (colors, menus, dialogs)
├── Docker Analysis Functions (counting, sizing)
├── Cleanup Functions (images, containers, volumes, cache)
├── Menu Functions (main menu, advanced menu)
└── Main Execution (argument handling, startup)
```

## 📊 Usage Examples

### Example 1: Clean Up Dangling Images
```bash
$ ./docker-cleaner.sh
> [1] Delete dangling images
⚠️  Found: 10 dangling images (~650MB)
🗑️  IMAGE ID       SIZE        CREATED
🗑️  17fa649ad8a2   671MB       2 days ago
🗑️  e60fcc7a368e   495MB       3 days ago
...
⚠️  10 dangling images (~650MB) really delete?
Confirm? (y/N): y
🧹 Deleting dangling images...
✅ 10 dangling images deleted
```

### Example 2: Full System Cleanup
```bash
$ ./docker-cleaner.sh --test
> [6] Full cleanup (all above)
🧪 TEST MODE: Would run docker rmi $(docker images -f "dangling=true" -q)
🧪 TEST MODE: Would run docker rm $(docker ps -a -q --filter "status=exited")
🧪 TEST MODE: Would run docker volume prune --force
🧪 TEST MODE: Would run docker builder prune --all --force
✅ Test mode completed - no actual deletions performed
```

### Example 3: Analyze Docker Usage
```bash
$ ./docker-cleaner.sh
> [5] Show detailed analysis
📊 Detailed Docker System Analysis

System Overview:
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          20        8         6.319GB   4.649GB (73%)
Containers      8         8         15.97MB   0B (0%)
Local Volumes   15        4         2.521GB   2.402GB (95%)
Build Cache     197       0         24.45GB   21.38GB

Image Statistics:
Total Images: 20
Dangling Images: 10
Running Containers: 8
Stopped Containers: 3
```

## 🔍 Advanced Options

### Advanced Menu Features
- **[1]** Show all images sorted by size
- **[2]** System statistics (`docker system df`)
- **[3]** Show all images (including active)
- **[4]** Docker version & system info
- **[5]** Toggle test mode

### Custom Integration
Both scripts can be integrated into automated workflows:

```bash
# Cron job for weekly cleanup
0 2 * * 0 /path/to/docker-cleaner-en.sh --test

# Docker compose integration
docker-compose down
./docker-cleaner.sh --test
docker-compose up -d --build
```

## 🐛 Troubleshooting

### Common Issues

#### "Docker daemon is not running"
```bash
# Start Docker Desktop manually
# Or wait for Docker Desktop to fully initialize
open -a Docker
```

#### "Permission denied"
```bash
# Make scripts executable
chmod +x docker-cleaner*.sh
```

#### "Command not found: docker"
```bash
# Add Docker to PATH or use Docker Desktop
export PATH="/usr/local/bin:$PATH"
```

#### Terminal Display Issues
- Ensure your terminal supports ANSI colors
- Use Terminal.app or iTerm2 on macOS
- Avoid running in basic text editors

### Debug Mode
Set verbose mode for troubleshooting:
```bash
# Enable verbose output
VERBOSE=true ./docker-cleaner.sh
```

## 📈 Performance Considerations

### Large Docker Environments
- Scripts are optimized for environments with hundreds of images/containers
- Pagination prevents overwhelming terminal output
- Progress indicators show operation status

### Network Considerations
- All operations work offline once Docker is running
- No external dependencies beyond Docker commands
- Fast execution with minimal system impact

## 🔄 Version History

### v1.0.0 (Current)
- ✅ Interactive menu system with beautiful UI
- ✅ Dangling images cleanup (primary feature)
- ✅ Container, volume, and build cache cleanup
- ✅ Test mode and safety features
- ✅ Detailed system analysis
- ✅ English and German versions
- ✅ macOS Terminal optimization

## 🤝 Contributing

### Development Setup
```bash
# Clone or download the scripts
# Test in safe environment first
./docker-cleaner.sh --test

# For development, you can modify safely
cp docker-cleaner.sh docker-cleaner-dev.sh
chmod +x docker-cleaner-dev.sh
```

### Code Style
- Use bash 3.2+ compatibility (macOS default)
- Follow existing function naming conventions
- Maintain color scheme consistency
- Keep menus aligned and visually balanced

## 📜 License

These scripts are provided as-is for Docker system maintenance. Feel free to modify and distribute as needed for your environment.

## 🙋‍♂️ Support

For issues or questions:
1. Check the troubleshooting section
2. Run with `--test` mode first
3. Ensure Docker Desktop is running
4. Verify terminal compatibility

## 📚 Additional Resources

- [Docker CLI Documentation](https://docs.docker.com/engine/reference/commandline/cli/)
- [Docker System Prune](https://docs.docker.com/engine/reference/commandline/system_prune/)
- [Docker Desktop for Mac](https://docs.docker.com/desktop/mac/install/)

---

**🎯 Primary Use Case**: The main purpose of these scripts is to safely remove dangling Docker images (`<none>:<none>`) that accumulate during build processes, reclaiming disk space while maintaining system safety through interactive confirmation dialogs and test mode capabilities.
