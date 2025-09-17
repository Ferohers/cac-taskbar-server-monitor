# AltanMon

A lightweight macOS menu bar app for monitoring servers via SSH.

## Features

- 🖥️ **Menu Bar Integration**: Lightweight app that lives in your macOS menu bar
- 🔧 **Easy Setup**: GUI configuration for multiple servers
- 📊 **Real-time Monitoring**: CPU usage, RAM usage, Docker containers, and network stats
- 🔒 **Secure**: SSH key or password authentication
- 🌓 **System Integration**: Follows macOS dark/light mode automatically
- ⚡ **Battery Efficient**: Optimized for M-series chips with minimal resource usage

## Requirements

- macOS 13.0 or later
- M-series Mac (Apple Silicon)
- SSH access to target servers

## Installation

1. Clone this repository
2. Run the build script:
   ```bash
   ./build.sh
   ```
3. Launch the app:
   ```bash
   ./AltanMon
   ```

## Configuration

On first launch, AltanMon will show a configuration dialog where you can add servers to monitor.

### Adding Servers

You can add servers in multiple ways:
- **First Launch**: Configuration dialog opens automatically
- **Menu Bar**: Click "Add Server..." from the menu
- **Preferences**: Click "Configure Servers..." to manage all servers

For each server, configure:
- **Server name**: Display name for identification
- **Hostname or IP**: Server address (e.g., 192.168.1.100 or server.example.com)
- **Username**: SSH username
- **Password**: Optional if using SSH key authentication
- **SSH Key Path**: Optional path to private key (e.g., ~/.ssh/id_rsa)
- **Port**: SSH port (default: 22)

### Managing Servers

- **Add**: Click "Add New Server" button in the configuration window
- **Remove**: Click "Remove" button on any server configuration
- **Edit**: Modify any field and click "Save"

The configuration is automatically saved to `~/AltanMon.json`.

## Server Requirements

Your servers should have SSH access enabled and support these commands for full functionality:

### Required Commands
- Basic SSH connectivity
- Standard Unix commands (`echo`, `awk`, etc.)

### Optional Commands (for enhanced monitoring)
- `top` or `sar` (for CPU usage)
- `free` or `vm_stat` (for memory usage)
- `docker` (for container monitoring)
- `/proc/net/dev` or `vnstat` (for network monitoring)

## Monitored Metrics

- **CPU Usage**: Percentage of CPU utilization
- **Memory Usage**: RAM usage percentage and total memory
- **Docker Containers**: List of running containers with status
- **Network Usage**: Upload/download speeds in Mbit/s
- **Connection Status**: Real-time connection monitoring

## Menu Bar Display

Click the AltanMon icon in your menu bar to see:

- Server status (connected/disconnected)
- Real-time metrics for each server
- Last update timestamp
- Quick access to preferences
- Quit option

## Troubleshooting

### Connection Issues
- Verify SSH access: `ssh username@hostname`
- Check firewall settings on target servers
- Ensure SSH key permissions are correct (600)
- Test with password authentication first

### Missing Metrics
- Some metrics require specific commands to be available
- Docker metrics only appear if Docker is installed and accessible
- Network monitoring may vary by server OS

### Performance
- Update interval is 30 seconds by default
- App uses minimal resources when running
- Servers are monitored in parallel for efficiency

## Development

The app is built with Swift and uses:
- Cocoa for macOS integration
- Foundation for core functionality
- Swift Package Manager for dependency management

### Project Structure
```
Sources/
├── main.swift              # App entry point
├── AppDelegate.swift       # Main app coordinator
├── Controllers/           # UI controllers
├── Views/                # UI components
├── Models/               # Data models
├── Managers/             # Business logic
├── Network/              # SSH communication
└── Resources/            # Assets and resources
```

## License

This project is open source. Feel free to modify and distribute.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.