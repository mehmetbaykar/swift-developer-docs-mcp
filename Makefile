.PHONY: build test resolve clean act-ci act-release act-release-build act-list

build:
	swift build

test:
	swift test -v

resolve:
	swift package resolve

clean:
	swift package clean

act-ci:
	act --container-architecture linux/amd64 \
		-P ubuntu-latest=catthehacker/ubuntu:full-latest \
		-W .github/workflows/ci.yml \
		--artifact-server-path /tmp/artifacts \
		push

act-release:
	act --container-architecture linux/amd64 \
		-P ubuntu-latest=catthehacker/ubuntu:full-latest \
		-W .github/workflows/release.yml \
		--secret-file .secrets \
		--artifact-server-path /tmp/artifacts \
		release

act-release-build:
	act --container-architecture linux/amd64 \
		-P ubuntu-latest=catthehacker/ubuntu:full-latest \
		-W .github/workflows/release.yml \
		--artifact-server-path /tmp/artifacts \
		-j build \
		release

act-list:
	act -l
