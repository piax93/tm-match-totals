PLUGIN_NAME=$(shell cat info.toml | grep ^name | grep -Eo '".+"' | tr -d '"' | tr ' ' _)
SOURCE_DIR=src
OUTPUT_FILE=$(PLUGIN_NAME).op
SOURCE_FILES=$(wildcard $(SOURCE_DIR)/*.as)
METADATA_FILES=info.toml LICENSE $(wildcard *.md)

.PHONY: all install-hooks

all: $(OUTPUT_FILE)

install-hooks:
	pre-commit install -f --install-hooks
	pre-commit run --all-files

$(OUTPUT_FILE): $(METADATA_FILES) $(SOURCE_FILES)
	zip $@ $(METADATA_FILES)
	cd $(SOURCE_DIR); zip -u ../$@ $(notdir $(SOURCE_FILES))
