__PHONY__: build build-deps build-deps-core build-deps-horizon

TAG?=organization-mainnet-v1.0-p26.1.0
CORE_REPO?=https://github.com/stellar/stellar-core.git
CORE_REF?=v26.1.0
CORE_CONFIGURE_FLAGS?=--disable-tests
HORIZON_REPO?=https://github.com/stellar/stellar-horizon.git
HORIZON_REF?=v26.0.0

build-deps: build-deps-core build-deps-horizon

build-deps-core:
	docker build --platform linux/amd64 -t stellar-core:$(CORE_REF) -f Dockerfile.core . \
	  --build-arg REF="$(CORE_REF)" \
	  --build-arg CORE_REPO="$(CORE_REPO)" \
	  --build-arg CONFIGURE_FLAGS="$(CORE_CONFIGURE_FLAGS)"

build-deps-horizon:
	docker build --platform linux/amd64 -t stellar-horizon:$(HORIZON_REF) -f Dockerfile.horizon --target builder . \
	  --build-arg REF="$(HORIZON_REF)" \
	  --build-arg HORIZON_REPO="$(HORIZON_REPO)"

build:
	$(MAKE) build-deps
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:$(TAG) -f Dockerfile . \
	  --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:$(CORE_REF) \
	  --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(HORIZON_REF)
