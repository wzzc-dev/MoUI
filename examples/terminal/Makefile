ROOT := ../..

.PHONY: test check fmt

test:
	cd $(ROOT) && moon test examples/terminal/app --target native && moon test examples/terminal/addon --target native && moon test examples/terminal/pty_host --target native && moon test examples/terminal/macos_skia/composition --target native

check:
	cd $(ROOT) && moon check examples/terminal/app --target native && moon check examples/terminal/addon --target native && moon check examples/terminal/pty_host --target native && moon check examples/terminal/macos_skia --target native && moon check examples/terminal/macos_skia/composition --target native

fmt:
	cd $(ROOT) && moon fmt examples/terminal/app examples/terminal/addon examples/terminal/pty_host examples/terminal/macos_skia examples/terminal/macos_skia/composition
