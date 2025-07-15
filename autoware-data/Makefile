.PHONY: help build clean

help:
	@echo "Available targets:"
	@echo "  build  - Build the Debian package using makedeb"
	@echo "  clean  - Remove build artifacts and downloaded files"
	@echo "  help   - Show this help message"

build:
	./genpkg.py --update
	makedeb -d

clean:
	rm -rf src pkg
	rm -f *.deb *.ddeb *.tar.gz *.tar.xz *.tar.bz2
	rm -f *.log *.buildinfo *.changes
	rm -f *.onnx *.table *.csv *.txt
	rm -f *_ml_package.param.yaml detection_class_remapper.param.yaml deploy_metadata.yaml
