# Makefile (pruned to only what’s used in README flows)
APP ?= jwt-demo-app
PORT ?= 3001
HOST ?= 127.0.0.1
REGISTRY ?=
IMAGE := $(if $(REGISTRY),$(REGISTRY)/,)$(APP)
TAG ?= $(shell git describe --always --dirty --tags 2>/dev/null || echo dev)

.PHONY: all build docker-build docker-run test stop clean pipeline \
        bootstrap kind-up kind-down k8s-kind-build k8s-kind-load k8s-kind-deploy k8s-kind-delete \
        helm-lint jwt istio-install istio-enable-injection istio-auth-deploy istio-expose istio-delete istio-allow-public

# ----- local (docker) -----
all: pipeline

build:
	npm ci || npm install

docker-build:
	docker build -t $(IMAGE):$(TAG) .

docker-run:
	-@docker rm -f $(APP) 2>/dev/null || true
	docker run -d --rm --name $(APP) -e HOST=0.0.0.0 -e PORT=3000 -p $(PORT):3000 $(IMAGE):$(TAG)

test:
	@echo "==> wait for app"
	@i=0; until curl -fsS "http://$(HOST):$(PORT)/" >/dev/null 2>&1; do \
	  i=$$((i+1)); [ $$i -gt 50 ] && echo "timeout waiting for app" && exit 1; sleep 0.2; done
	@echo "==> /public"
	@code=$$(curl -sS -w '%{http_code}\n' "http://$(HOST):$(PORT)/public" -o /tmp/out.$(APP)); \
	if [ "$$code" != "200" ]; then echo "expected 200, got $$code"; cat /tmp/out.$(APP); exit 1; fi; \
	sed 's/^/  /' </tmp/out.$(APP)
	@echo "\n==> /private (no token)"
	@code=$$(curl -sS -w '%{http_code}\n' "http://$(HOST):$(PORT)/private" -o /tmp/out.$(APP).nohdr); \
	if [ "$$code" != "401" ]; then echo "expected 401, got $$code"; cat /tmp/out.$(APP).nohdr; exit 1; fi; \
	echo "  got expected 401"
	@echo "==> /private (with dummy JWT)"
	@TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJmb28iOiJiYXIifQ.c2ln; \
	code=$$(curl -sS -w '%{http_code}\n' -H "Authorization: Bearer $$TOKEN" "http://$(HOST):$(PORT)/private" -o /tmp/out.$(APP).jwt); \
	if [ "$$code" != "200" ]; then echo "expected 200, got $$code"; cat /tmp/out.$(APP).jwt; exit 1; fi; \
	sed 's/^/  /' </tmp/out.$(APP).jwt

stop:
	-@docker rm -f $(APP) 2>/dev/null || true

clean: stop
	-@docker rmi $(IMAGE):$(TAG) 2>/dev/null || true

pipeline: build docker-build docker-run test stop
	@echo "OK: $(IMAGE):$(TAG)"

# ----- tools/bootstrap -----
bootstrap:
	chmod +x scripts/bootstrap-tools.sh
	./scripts/bootstrap-tools.sh

# ----- kind (k8s-in-docker) -----
kind-up:
	@if ! kind get clusters 2>/dev/null | grep -q '^jwt-lab$$'; then \
	  kind create cluster --name jwt-lab --config kind-cluster.yaml; \
	else echo "kind cluster 'jwt-lab' exists"; fi

kind-down:
	-kind delete cluster --name jwt-lab

k8s-kind-build: kind-up
	docker build -t jwt-demo-app:dev .

k8s-kind-load: k8s-kind-build
	kind load docker-image jwt-demo-app:dev --name jwt-lab

k8s-kind-deploy: k8s-kind-load
	helm upgrade --install jwt-demo-app ./helm/jwt-demo-app --namespace demo --create-namespace \
	  --set image.repository=jwt-demo-app --set image.tag=dev

k8s-kind-delete:
	helm uninstall jwt-demo-app -n demo || true
	kubectl delete ns demo --ignore-not-found

helm-lint:
	-helm lint ./helm/jwt-demo-app
	-helm lint ./helm/istio-auth

# ----- JWT helper -----
jwt:
	chmod +x scripts/gen-rs256.sh
	ISSUER="$(ISSUER)" KID="$(KID)" scripts/gen-rs256.sh

# ----- istio -----
istio-install:
	istioctl install -y --set profile=demo

istio-enable-injection:
	kubectl label namespace demo istio-injection=enabled --overwrite
	kubectl -n demo rollout restart deploy/jwt-demo-app

istio-auth-deploy:
	@test -n "$(ISSUER)" || (echo "ERROR: set ISSUER, e.g. ISSUER=https://demo-issuer.local make istio-auth-deploy"; exit 1)
	@test -f jwks.json || (echo "ERROR: jwks.json missing. Generate it with: ISSUER=\"$$ISSUER\" KID=demo-kid scripts/gen-rs256.sh"; exit 1)
	helm upgrade --install istio-auth ./helm/istio-auth -n demo --create-namespace \
	  --set host=demo.localhost \
	  --set issuer="$(ISSUER)" \
	  --set-file jwks=./jwks.json

# Expose ingress without port-forward (expects kind-cluster.yaml to map host 8080->node 30080)
istio-expose:
	kubectl -n istio-system patch svc istio-ingressgateway \
	  -p '{"spec":{"type":"NodePort","ports":[{"name":"http2","port":80,"targetPort":8080,"protocol":"TCP","nodePort":30080}]}}' || true

istio-delete:
	helm uninstall istio-auth -n demo || true
	kubectl delete ns demo --ignore-not-found
	istioctl uninstall -y --purge || true

# Allow public access via Istio AuthorizationPolicy
istio-allow-public:
	kubectl apply -n demo -f helm/istio-auth/templates/authorizationpolicy-public.yaml