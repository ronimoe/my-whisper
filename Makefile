MODEL ?= large-v3-turbo

.PHONY: build app run model deps clean test

build:
	swift build -c release

# XCTest needs the full Xcode toolchain; Command Line Tools alone lacks it.
test:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

app: build
	./scripts/make-app.sh

run: app
	open build/MyWhisper.app

model:
	./scripts/download-model.sh $(MODEL)

# Optional: build a self-contained whisper-server for bundling/distribution.
# Not needed when whisper-cpp is installed via Homebrew. Requires cmake.
deps:
	git -C vendor/whisper.cpp pull 2>/dev/null || git clone --depth 1 https://github.com/ggml-org/whisper.cpp vendor/whisper.cpp
	cmake -S vendor/whisper.cpp -B vendor/whisper.cpp/build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DGGML_METAL_EMBED_LIBRARY=ON -DWHISPER_BUILD_TESTS=OFF
	cmake --build vendor/whisper.cpp/build -j

clean:
	rm -rf .build build
