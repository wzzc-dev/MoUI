# MoonBit Project Commands

target := "js"

default: check test

fmt:
    moon fmt

check:
    moon check --target {{target}}

test:
    moon test --target {{target}}

test-update:
    moon test --update --target {{target}}

info:
    moon info

clean:
    moon clean

release-check: fmt info check test

release-check-all:
    just release-check
    just target=native check test
