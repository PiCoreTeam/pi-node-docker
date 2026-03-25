__PHONY__: build build-deps build-deps-core build-deps-horizon

TAG?=community-v1.4-p25.2.1
CORE_REPO?=https://github.com/stellar/stellar-core.git
CORE_REF?=v25.2.1-external
CORE_VERSION?=v25.2.1
CORE_CONFIGURE_FLAGS?=--disable-tests
HORIZON_REF?=v25.0.0

build-deps: build-deps-core build-deps-horizon

build-deps-core:
	docker build --platform linux/amd64 -t stellar-core:$(CORE_REF) -f Dockerfile.core . \
	  --build-arg REF="$(CORE_REF)" \
	  --build-arg CORE_REPO="$(CORE_REPO)" \
	  --build-arg CONFIGURE_FLAGS="$(CORE_CONFIGURE_FLAGS)" \
	  --build-arg CORE_VERSION="$(CORE_VERSION)"

build-deps-horizon:
	docker build --platform linux/amd64 -t stellar-horizon:$(HORIZON_REF) -f Dockerfile.horizon --target builder . --build-arg REF="$(HORIZON_REF)"

build:
	$(MAKE) build-deps
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:$(TAG) -f Dockerfile . \
	  --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:$(CORE_REF) \
	  --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(HORIZON_REF)
