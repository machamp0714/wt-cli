.PHONY: test lint
test:
	bats tests
lint:
	shellcheck -x bin/wt lib/*.sh
