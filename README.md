# MPRAmpController

`MPRAmpController` is a Swift Vapor web application that controls the [Monoprice "6 Zone Home Audio Multizone Controller and Amplifier Kit"](https://www.monoprice.com/product?p_id=10761). In theory this should also work for the [Dayton Audio DAX66](https://www.daytonaudio.com/product/1252/dax66-6-source-6-zone-distributed-audio-system) __but has not been tested__. 

Control is done using the RS-232 port with either a Raspberry Pi or Mac and a serial to USB cable. I'm using [this one](https://www.amazon.com/dp/B00QUZY4UG/ref=cm_sw_em_r_mt_dp_U_xJQaFbN6SVJ4M). 

This implementation uses [ORSSerialPort](https://github.com/armadsen/ORSSerialPort) which is currently unavailable on Linux. As such, this is a Mac only Vapor application. 

I did put my previous implementation using the Mac and Linux Compatible [SwiftSerial](https://github.com/yeokm1/SwiftSerial) in [this repository](https://github.com/SpencerCurtis/MPRAmpController-SwiftSerial) if you are interested in something that can be potentially run on a Raspberry Pi or similar inexpensive hardware. The implementation using SwiftSerial was working reasonably well on my Mac mini but does have some trouble when used with a Raspberry Pi for some reason. That's the main reason I chose to switch over to using ORSSerialPort.

## 🚀 Build & Deployment

This application is designed for deployment to an **Intel Mac mini running macOS 10.15.7** (Catalina). The build system creates a standalone binary with embedded templates for maximum compatibility.

### Quick Start

```bash
# Build for Intel x86_64 deployment
./build-x86.sh

# Deploy to Mac mini
scp binary/Run user@macmini:./

# Run on Mac mini
./Run
```

Access the web interface at `http://localhost:8080`

### Build Script Features

- **Automated Template Embedding**: Leaf templates are automatically embedded into the binary
- **Intel x86_64 Target**: Cross-compiles for Intel Mac mini deployment
- **Standalone Binary**: No external template files required
- **macOS 10.15.7 Compatible**: Works on older Mac hardware

## 📝 Template Development

The application uses **automated template embedding** for maximum deployment compatibility:

### ✅ Template Workflow

1. **Edit Templates**: Modify `.leaf` files in `Sources/App/Resources/Views/`
2. **Build**: Run `./build-x86.sh` (templates are automatically embedded)
3. **Deploy**: Transfer `binary/Run` to target Mac mini

### 🤖 Automated Template System

- **Source Templates**: `Sources/App/Resources/Views/*.leaf`
- **Auto-Generated**: `Sources/App/Models/EmbeddedTemplates.swift` (created during build)
- **Embedded Binary**: Templates bundled into `binary/Run` for standalone deployment

**⚠️ Important**: Never edit `EmbeddedTemplates.swift` manually - it's regenerated on each build!

### Template Files

- `zones.leaf` - Main zone controller interface with modern CSS/JavaScript
- `test.leaf` - Simple test page for debugging

## 🏗️ Architecture

### Target Platform
- **Architecture**: Intel x86_64 (not ARM/Apple Silicon)
- **OS**: macOS 10.15.7 (Catalina) and newer
- **Hardware**: Intel Mac mini with USB serial connection

### Software Stack
- **Backend**: Swift Vapor 4
- **Database**: SQLite (for zone names)
- **Serial**: ORSSerial framework (with protocol-based abstraction)
- **Frontend**: Leaf templates with embedded CSS/JavaScript
- **Deployment**: Standalone binary with embedded templates

### Zone Controller Architecture

The application uses a **protocol-based architecture** that supports both real hardware and mock implementations:

- **`ZoneControllerProtocol`**: Defines the interface for zone control
- **`SerialController`**: Real hardware implementation using ORSSerial
- **`MockZoneController`**: Simulated hardware for local development
- **Environment-based selection**: Automatic switching via `USE_MOCK_CONTROLLER` environment variable

### Hardware Requirements
- USB serial device with "usbserial" in the device name
- Multi-zone amplifier controller connected via USB

## 🛠️ Development

### Local Development with Mock Controller

For faster development and testing without hardware:

```bash
# Run locally with simulated hardware
./run-local.sh
```

This starts the application with a **Mock Zone Controller** that:
- Simulates realistic zone states and responses
- Allows full UI testing without serial hardware
- Includes configurable delays and error simulation
- Persists changes in memory during development

Access the local development server at `http://localhost:8001`

### Building for Deployment
```bash
# Incremental build (fast)
./build-x86.sh

# Clean build (slower, but guaranteed fresh)
./build-x86.sh --clean
```

### Template Development
```bash
# Edit templates
vim Sources/App/Resources/Views/zones.leaf

# Templates are automatically embedded during build
./build-x86.sh

# Deploy updated binary
scp binary/Run user@macmini:./
```

### Code Structure
- `Sources/App/Controllers/ZoneControllerProtocol.swift` - Zone controller interface and base class
- `Sources/App/Controllers/SerialController.swift` - Real hardware implementation
- `Sources/App/Controllers/MockZoneController.swift` - Mock hardware for development
- `Sources/App/Resources/Views/` - Leaf templates (edit these)
- `Sources/App/Models/EmbeddedTemplates.swift` - Auto-generated (don't edit)
- `generate-embedded-templates.sh` - Template embedding script
- `build-x86.sh` - Main build script
- `run-local.sh` - Local development with mock controller

## 📦 Files

### Source Files
- `Sources/App/Resources/Views/*.leaf` - Edit these template files
- `Sources/App/Controllers/SerialController.swift` - Main controller
- `build-x86.sh` - Build script with automated template embedding

### Generated Files  
- `Sources/App/Models/EmbeddedTemplates.swift` - Auto-generated, don't edit
- `binary/Run` - Standalone executable for deployment
- `binary/Resources/` - Resource files for development/fallback

## 💡 Compatibility

This project includes an embedded template system for compatibility with older macOS versions that don't support Swift Package Manager resource bundling. The templates are automatically embedded as strings during the build process, creating a truly standalone binary.

For detailed information about the embedded template system, see `EMBEDDED_TEMPLATES.md`.

