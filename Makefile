__PHONY__: build build-testing

build:
	docker build --platform linux/amd64 -t stellar/quickstart -f Dockerfile .

build-testing:
	docker build --platform linux/amd64 -t stellar/quickstart:testing -f Dockerfile.testing
