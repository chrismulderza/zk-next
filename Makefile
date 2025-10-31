.PHONY: all build test clean install release

VERSION_FILE = VERSION
CHANGELOG_FILE = CHANGELOG.md
INSTALL_DIR = $(HOME)/.local/zk-next
BIN_DIR = $(HOME)/.local/bin

all: build test

build:
	@echo "Building zk-next..."
	# Add build steps here, e.g., rubocop lib/ if available

test:
	@echo "Running tests..."
	ruby -Ilib test/models/note_test.rb
	@if command -v bats >/dev/null 2>&1; then \
		bats test/zk.bats; \
	else \
		echo "bats not installed, skipping shell script tests"; \
	fi

clean:
	@echo "Cleaning..."

install:
	mkdir -p $(INSTALL_DIR)
	cp -r bin lib examples $(INSTALL_DIR)/
	mkdir -p $(BIN_DIR)
	ln -sf $(INSTALL_DIR)/bin/zk $(BIN_DIR)/zk
	@if [ ! -d "$(HOME)/.config/zk-next" ]; then \
		mkdir -p $(HOME)/.config/zk-next/templates; \
		cp examples/config/config.yaml $(HOME)/.config/zk-next/; \
		cp lib/defaults/default.erb $(HOME)/.config/zk-next/templates/default.erb; \
		echo "Config and templates installed to $(HOME)/.config/zk-next"; \
	else \
		echo "Config directory $(HOME)/.config/zk-next already exists, skipping config installation"; \
	fi
	@echo "Installed zk-next to $(INSTALL_DIR)"
	@echo "Symlink created: $(BIN_DIR)/zk"

release:
	@current_version=$$(cat $(VERSION_FILE)); \
	IFS='.' read -r major minor patch <<< "$$current_version"; \
	new_patch=$$((patch + 1)); \
	new_version="$$major.$$minor.$$new_patch"; \
	echo $$new_version > $(VERSION_FILE); \
	last_tag=$$(git describe --tags --abbrev=0 2>/dev/null || echo ""); \
	if [ -z "$$last_tag" ]; then \
		commits=$$(git log --oneline --no-merges); \
	else \
		commits=$$(git log --oneline --no-merges $$last_tag..HEAD); \
	fi; \
	echo -e "\n## $$new_version" >> $(CHANGELOG_FILE); \
	echo "$$commits" | sed 's/^/- /' >> $(CHANGELOG_FILE); \
	git add $(VERSION_FILE) $(CHANGELOG_FILE); \
	git commit -m "Release v$$new_version"; \
	git tag v$$new_version; \
	@echo "Released v$$new_version"
