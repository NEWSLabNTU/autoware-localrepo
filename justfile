# Autoware Local Repository

# Default recipe: list available build targets
default:
    @echo "Build targets:"
    @echo "  cd 1.5.0/amd64 && just all    # Autoware 1.5.0 for AMD64"
    @echo "  cd 1.5.0/jp62 && just all     # Autoware 1.5.0 for JetPack 6.2"
    @echo "  cd 2025.02/amd64 && just all  # Autoware 2025.02 for AMD64"
    @echo "  cd 2025.02/jp60 && just all   # Autoware 2025.02 for JetPack 6.0"
