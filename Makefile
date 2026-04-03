APP_NAME := Typeless
INSTALL_DIR ?= $(HOME)/Applications

.PHONY: build run install install-system clean test verify

build:
	./scripts/build-app.sh

run:
	./scripts/run-app.sh

install:
	INSTALL_DIR="$(INSTALL_DIR)" ./scripts/install-app.sh

install-system:
	INSTALL_DIR="/Applications" ./scripts/install-app.sh

clean:
	rm -rf .build dist

test:
	swift test

verify:
	./scripts/verify-app.sh
