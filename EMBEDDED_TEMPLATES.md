# Embedded Templates Solution for MPRAmpController

## Problem
When deploying the MPRAmpController binary to older Macs (macOS 10.15.7), the Leaf template files need to be bundled into the binary since Swift Package Manager's resource bundling was not available in older versions.

## Solution
The application now includes an embedded templates system that:

1. **Stores templates as strings**: All Leaf templates are embedded as static string literals in `Sources/App/Models/EmbeddedTemplates.swift`
2. **Creates runtime files**: When the app starts, if no template files are found, it extracts the embedded templates to a temporary directory
3. **Maintains Leaf compatibility**: Leaf continues to work normally with the extracted template files

## How It Works

### 1. Automated Template Generation (`generate-embedded-templates.sh`)
- Script automatically reads all `.leaf` files from `Sources/App/Resources/Views/`
- Generates `EmbeddedTemplates.swift` with templates as Swift raw string literals (`#"""..."""#`)
- Preserves all formatting, quotes, and special characters without escaping
- Runs automatically during build process

### 2. Template Storage (`EmbeddedTemplates.swift`)
- Auto-generated file containing templates as static string properties
- Templates are bundled directly into the binary at compile time
- **DO NOT EDIT MANUALLY** - file is regenerated on each build

### 3. Runtime Extraction (`configure.swift`)
- At startup, the app checks for template files in development and deployment locations
- If no templates are found, it calls `EmbeddedTemplates.createTempViewsDirectory()`
- This creates a temporary directory and writes all templates as `.leaf` files
- Leaf is configured to use this temporary directory

### 4. Template Fallback Hierarchy
1. **Development**: `Sources/App/Resources/Views/` (when running from source)
2. **Deployment**: `Resources/Views/` (when using copied resource files)
3. **Embedded**: Temporary directory with extracted templates (macOS 10.15.7 compatibility)

## Benefits

✅ **Standalone Binary**: No external template files required for deployment
✅ **macOS 10.15.7 Compatible**: Works on older Macs that don't support SPM resource bundling
✅ **No Code Changes**: Existing Leaf templates and view rendering code unchanged
✅ **Fast Startup**: Templates are extracted once at startup, not on every request
✅ **Development Friendly**: Still uses actual template files during development
✅ **Automated Sync**: Templates are automatically embedded from source files on each build
✅ **No Manual Copying**: Eliminates error-prone manual string copying process

## File Structure

```
Sources/App/Models/EmbeddedTemplates.swift  # Auto-generated template storage
Sources/App/configure.swift                 # Runtime extraction logic
Sources/App/Resources/Views/                # Source template files
generate-embedded-templates.sh             # Template generation script
build-x86.sh                               # Build script (runs template generation)
binary/Run                                  # Standalone executable with embedded templates
```

## Usage

### Building for Deployment
```bash
./build-x86.sh
```

The binary will now work standalone on the target Intel Mac mini without requiring any template files.

### Updating Templates
1. Modify templates in `Sources/App/Resources/Views/`
2. Rebuild with `./build-x86.sh` (templates are automatically embedded)

The `EmbeddedTemplates.swift` file is automatically generated from your `.leaf` files during the build process.

## Technical Details

- **Template Size**: Current templates are fully embedded (~20KB total)
- **Memory Usage**: Templates are loaded once at startup
- **Temporary Files**: Created in system temp directory, cleaned up automatically
- **Performance**: No noticeable impact on startup or runtime performance

## Compatibility
- ✅ macOS 10.15.7 (Catalina) and newer
- ✅ Intel x86_64 architecture
- ✅ Swift 5.2+ with Vapor 4
- ✅ Leaf 4.2.4

This solution provides maximum compatibility while maintaining the development workflow and Leaf's powerful templating features. 