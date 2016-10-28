NGINX-SSL-PROXY_DIR        := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
TECHOPS_REPO               := ${NGINX-SSL-PROXY_DIR}/../techops
TECHOPS_ENV_DIR            := ${TECHOPS_REPO}/environments
KUBE_SCRIPT                := ${TECHOPS_ENV_DIR}/run-kubectl.sh
PYTHON                     := $(shell python3 --version >/dev/null 2>&1 && echo python3 || echo python)

GCP_ENV                    := dev
GCP_REGION                 := gcp-west
GCP_PROJECT                := loanpal-${GCP_ENV}

VERSION_HASH               := HEAD
VERSION                    := $(shell git log --pretty=format:"%cd-%h" --date="format:%Y%m%d" -1 ${VERSION_HASH})

VERSION_TAG                := ${GCP_PROJECT}/nginx-ssl-proxy:${VERSION}
GCP_VERSION_TAG            := gcr.io/${VERSION_TAG}
LATEST_TAG                 := ${GCP_PROJECT}/nginx-ssl-proxy:latest
GCP_LATEST_TAG             := gcr.io/${LATEST_TAG}

TIMESTAMP                  := $(shell date '+%s')
TMP_BRANCH                 := gcp-build-${TIMESTAMP}
CURRENT_BRANCH             := $(shell git rev-parse --abbrev-ref HEAD)

##
#       Deploy the code to the GCP_ENV environment.
##
gcp-build:
	mkdir -p builds/${VERSION}
	git --work-tree=builds/${VERSION} checkout HEAD -- .

	@echo "Building container ${VERSION_TAG} in builds/${VERSION}"
	cd builds/${VERSION}; docker build -t ${VERSION_TAG} -f Dockerfile .
	docker tag ${VERSION_TAG} ${GCP_VERSION_TAG}
	gcloud docker push ${GCP_VERSION_TAG}
	rm -rf builds/${VERSION}

gcp-push: gcp-build
	@echo "Tagging ${VERSION_TAG} as ${LATEST_TAG}"
	docker tag ${VERSION_TAG} ${LATEST_TAG}
	docker tag ${LATEST_TAG} ${GCP_LATEST_TAG}
	gcloud docker push ${GCP_LATEST_TAG}

deploy: gcp-push
	@echo "---------- Deploying to ${GCP_ENV} -----------"
	${KUBE_SCRIPT} -e ${GCP_PROJECT} -l ${GCP_REGION} -c db set image \
		deployment/nginx-ssl-proxy-dc nginx-ssl-proxy-dc=${GCP_VERSION_TAG}

