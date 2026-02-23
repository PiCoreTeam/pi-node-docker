__PHONY__: build build-cli-image

build:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:organization_mainnet-v1.0-p19.9 -f Dockerfile .

build-cli-image:
	docker build --platform linux/amd64 --build-arg ENABLE_AUTO_MIGRATIONS=true -t pinetwork/pi-node-docker:organization_mainnet-v1.0-p19.9-cli -f Dockerfile .
