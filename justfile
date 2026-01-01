# Autoware Local Repository Build Automation

# Default recipe: list all available recipes
default:
    @just --list

# Build a specific version (e.g., just build 1.5.0)
build version:
    cd {{version}} && just all

# Create APT repository from all version outputs
create-repo:
    mkdir -p repo/pool/main
    @echo "Copying packages to repo pool..."
    -cp 1.5.0/output/*/*.deb repo/pool/main/ 2>/dev/null
    -cp 2025.02/output/*/*.deb repo/pool/main/ 2>/dev/null
    @echo "Generating Packages index..."
    cd repo && dpkg-scanpackages pool/main /dev/null > Packages
    cd repo && gzip -k -f Packages
    @echo "Repository created in repo/"

# Build common packages (autoware-localrepo)
build-common:
    cd common/autoware-localrepo && dpkg-buildpackage -us -uc -b
    mkdir -p repo/pool/main
    mv common/*.deb repo/pool/main/ 2>/dev/null || true

# Clean all build artifacts
clean:
    rm -rf repo/
    cd 1.5.0 && just clean 2>/dev/null || true
    cd 2025.02 && just clean 2>/dev/null || true

# Show repository structure
tree:
    @echo "=== Repository Structure ==="
    find . -type f -name "*.deb" 2>/dev/null | head -20 || echo "No .deb files found"
