# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Duman is a lightweight macOS menu bar application for monitoring remote servers via SSH. It's built with Swift using Cocoa frameworks and optimized for Apple Silicon (M-series) chips with power-efficient monitoring.

## Architecture

### Core Components

- **AppDelegate**: Main application coordinator managing status bar, server monitoring, and window lifecycle
- **ServerManager**: Handles server configuration persistence and credential management via Keychain
- **ServerMonitor**: Orchestrates periodic monitoring of all servers using background queues
- **SSHClient**: Executes remote SSH commands to gather system metrics (CPU, memory, Docker containers, network, disk)
- **MenuBarController**: Manages the menu bar UI and real-time data display
- **CredentialManager**: AES-256 encrypted storage for SSH keys and passwords
- **PowerManager**: Optimizes monitoring intervals based on system power state

### Data Flow

1. Server configurations and encrypted credentials stored in `~/Library/Application Support/Duman/.Duman-secret`
2. Encryption key stored in UserDefaults for credential encryption/decryption
3. ServerMonitor creates background tasks for each server
4. SSHClient connects and executes monitoring commands
5. Data flows back to MenuBarController for UI updates
6. PowerManager adjusts monitoring frequency based on battery/power state

### Key Models

- **ServerConfig**: Server connection details with encrypted credential fields
- **ServerData**: Runtime monitoring data (CPU, memory, Docker containers, network stats)
- **DockerContainer**: Container information with start times and status

## Common Development Commands

### Build and Run
```bash
# Build the app
./build.sh

# Run the built app
open ./Duman.app

# Quick development build
swift build -c release
```

### Testing SSH Connections
```bash
# Test SSH connectivity manually
ssh -o ConnectTimeout=15 -o BatchMode=yes username@hostname

# Test with SSH key
ssh -i ~/.ssh/id_rsa username@hostname

# Test with sshpass (password auth)
sshpass -p 'password' ssh username@hostname
```

### Debugging
```bash
# View app logs (when running from terminal)
./Duman.app/Contents/MacOS/Duman

# Monitor system power state
pmset -g ps

# Check encrypted config file
cat ~/Library/Application\ Support/Duman/.Duman-secret
```

## Development Guidelines

### SSH Command Construction
- All SSH commands use strict connection parameters for reliability
- Commands are properly escaped to handle special characters and nested quotes  
- Timeouts set to 15 seconds with keep-alive configuration
- Both SSH key and password authentication supported via Keychain

### Power Management
- Monitoring intervals automatically adjust based on power state (battery vs plugged in)
- Background activities properly managed to prevent system sleep interruption
- Timers use tolerance settings for power efficiency
- Custom refresh intervals range from 7 seconds to 10 minutes

### UI Architecture
- Menu bar app using NSStatusItem with custom MenuBarController
- Settings window uses sidebar navigation with tabbed content areas
- All UI updates happen on main queue, monitoring on background queues
- SwiftUI-style constraint-based layouts with proper auto-resizing

### Credential Storage
- Server credentials are encrypted client-side with AES-GCM and stored in `.Duman-secret`
- Encryption key is generated on first run and stored in UserDefaults under `DumanEncryptionKey`
- SSH keys are written to secure temporary files (chmod 600) only when needed for SSH connections
- Temporary key files are cleaned up immediately after use

### Error Handling
- SSH connection failures gracefully handled with retry logic
- Server unreachability doesn't crash monitoring of other servers
- UI shows connection status and error messages to users
- Malformed server responses logged but don't interrupt monitoring cycle

## File Structure Notes

- `Sources/main.swift`: App entry point setting activation policy for menu bar apps
- `Sources/Controllers/`: UI controllers including MenuBarController
- `Sources/Managers/`: Business logic (ServerManager, ServerMonitor, SettingsManager, etc.)
- `Sources/Models/`: Data models and structures
- `Sources/Network/SSHClient.swift`: All SSH communication and command execution
- `Sources/UI/`: Window controllers and views
- `build.sh`: Comprehensive build script handling icon generation, code signing, and app bundle creation

## Platform-Specific Considerations

### macOS Integration
- Uses NSStatusBar for menu bar presence
- Follows system dark/light mode automatically
- Integrates with macOS notification system
- Code signed for distribution
- Uses macOS-native icon formats (.icns) with multiple resolutions

### Apple Silicon Optimization
- Compiler flags in Package.swift optimize for M-series chips
- Power-efficient monitoring respects battery state
- ARM64-specific optimizations enabled in release builds

## Configuration

### Server Storage
Configuration file: `~/Library/Application Support/Duman/.Duman-secret` (JSON format)

### Settings Management
- Advanced settings include custom refresh intervals and Docker container visibility
- Notification settings per server with metric thresholds
- All settings auto-save and persist across app restarts

### Monitoring Metrics
- **CPU Usage**: Calculated from /proc/stat total/idle time differences
- **Memory**: Uses `free -m` on Linux, `vm_stat` on macOS servers  
- **Docker**: Supports both standalone containers and docker-compose services
- **Network**: Raw byte counts from /proc/net/dev for speed calculations
- **Disk**: Main filesystem usage from `df` command
- **Ping**: Local ping measurements for latency monitoring

## Security Considerations

- All credentials encrypted with AES-256-GCM, never stored in plain text
- SSH strict host key checking disabled for dynamic server environments
- Temporary SSH key files created with restrictive permissions (600)
- Automatic cleanup of temporary credential files
- Uses secure SSH connection parameters with timeouts