APP_NAME := Typeless
INSTALL_DIR ?= $(HOME)/Applications

.PHONY: build run install clean test

build:
	./scripts/build-app.sh

run:
	./scripts/run-app.sh

install:
	INSTALL_DIR="$(INSTALL_DIR)" ./scripts/install-app.sh

clean:
	rm -rf .build dist

test:
	swift test
