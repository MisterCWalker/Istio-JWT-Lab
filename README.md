# Istio JWT Lab (Node.js + kind + Istio)

Welcome to the Istio JWT Lab! In this guide, we'll walk you through running a simple Node.js (Express) application that demonstrates how to secure routes using JWT (JSON Web Tokens) with Istio. We'll cover three main scenarios: running the app locally, running it inside Kubernetes (using kind), and running it inside Kubernetes with Istio enforcing JWT authentication.

This guide is designed for apprentices and beginners, so each step includes explanations of what commands do and why they are important.

---

## Project Structure

Before we begin, let's familiarize ourselves with the project's layout. Knowing where files live helps you understand how the app and its infrastructure are organized.

```
.
├── Dockerfile
├── Makefile
├── package.json
├── server.js
├── scripts/
│   ├── bootstrap-tools.sh     # Installs necessary tools like kind, kubectl, helm, istioctl, jq, openssl, pre-commit
│   └── gen-rs256.sh           # Generates RS256 keypair, jwks.json, and token.txt for JWT authentication
└── helm/
    ├── jwt-demo-app/          # Helm chart for deploying the app
    └── istio-auth/            # Helm chart for Istio Gateway, RequestAuthentication, and AuthorizationPolicy
```

- **Dockerfile**: Defines how to build the container image for the app.
- **Makefile**: Contains commands to automate common tasks like building, deploying, and cleaning up.
- **server.js**: The Node.js application code.
- **scripts/**: Helpful scripts for setting up tools and generating JWT keys and tokens.
- **helm/**: Helm charts for deploying the app and Istio configurations.

---

## 1) Install Tools (One-Time Setup)

Before running the app or deploying it anywhere, you need to have several tools installed. These tools help you build images, manage Kubernetes clusters, and work with Istio.

### Step 1: Install Required Tools Using Makefile

Run the following command in your terminal:

```bash
make bootstrap
```

**What this does:**

- This command runs a script that installs all the necessary tools such as:
  - **Docker** (usually preinstalled)
  - **kind** (Kubernetes in Docker, lets you run a local Kubernetes cluster)
  - **kubectl** (Kubernetes command-line tool)
  - **helm** (package manager for Kubernetes)
  - **istioctl** (Istio command-line tool)
  - **jq** (tool for processing JSON)
  - **openssl** (cryptography toolkit)
  - **pre-commit** (helps manage git hooks)

### Step 2: Manual Installation (Alternative)

If you prefer to install tools manually or want to understand how the bootstrap script works, you can run:

```bash
chmod +x scripts/bootstrap-tools.sh
./scripts/bootstrap-tools.sh
```

This makes the script executable and runs it, installing the tools mentioned above.

**Why this matters:**

Having these tools installed is essential before you can build images, create Kubernetes clusters, or configure Istio. Without them, the rest of the lab won't work.

---

## 2) Scenarios: Running the App

We'll now explore three scenarios to run the app, starting from the simplest (local) to more advanced (Kubernetes with Istio).

---

### Scenario 1: Run the App Locally (No Orchestration)

This is the simplest way to run the app on your own machine without Kubernetes or Istio.

#### Using Makefile (Automated)

The Makefile automates the build, run, test, and stop steps for you.

- To start the app, build the image, run the container, test endpoints, and then stop the container, run:

```bash
make pipeline
```

**What happens:**

- Installs Node.js dependencies.
- Builds a Docker image named `jwt-demo-app:dev`.
- Runs the container locally, exposing the app.
- Tests the `/public` and `/private` endpoints.
- Stops the container after tests.

- To stop the app manually (if needed):

```bash
make stop
```

#### Manual Steps

If you want to run the app step-by-step manually, follow these commands:

- Build the Docker image:

```bash
docker build -t jwt-demo-app:dev .
```

- Run the container with environment variables `HOST` and `PORT` set:

```bash
docker run -d --rm --name jwt-demo-app -e HOST=0.0.0.0 -e PORT=3001 -p 3001:3001 jwt-demo-app:dev
```

- Test the endpoints:

```bash
curl http://localhost:3001/public
```
- This should return a 200 OK response without requiring any authentication.

```bash
curl -i http://localhost:3001/private
```
- This will return a 401 Unauthorized because no JWT token is provided.

```bash
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJmb28iOiJiYXIifQ.c2ln" http://localhost:3001/private
```
- This attempts to access the private route with a token (replace with a valid token to succeed).

- To stop the container manually:

```bash
docker rm -f jwt-demo-app
```

**Why this scenario matters:**

Running locally helps you understand how the app works without the complexity of Kubernetes or Istio. It's a good starting point to verify the app functions as expected.

---

### Scenario 2: Run the App in Kubernetes (kind) — No Istio

Now we will run the app inside a Kubernetes cluster created locally using `kind`. This simulates a real cloud environment but without Istio security features.

#### Using Makefile (Automated)

Start by creating a local Kubernetes cluster and deploying the app:

```bash
make kind-up
make k8s-kind-deploy
```

- `make kind-up` creates a local Kubernetes cluster named `jwt-lab` using the configuration in `kind-cluster.yaml`.
- `make k8s-kind-deploy` builds the Docker image, loads it into the kind cluster, and deploys the app using Helm into the `demo` namespace.

Test the endpoints by accessing the app's Kubernetes Service exposed as a NodePort on localhost port `3000`:

```bash
curl http://localhost:3000/public
```
- Should return 200 OK without authentication.

```bash
curl -i http://localhost:3000/private
```
- Should return 401 Unauthorized because no token is provided.

```bash
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJmb28iOiJiYXIifQ.c2ln" http://localhost:3000/private
```
- Attempts to access private route with a token.

Clean up the cluster and deployment:

```bash
make k8s-kind-delete
make kind-down
```

#### Manual Steps

If you want to do it yourself:

```bash
# Create the cluster
kind create cluster --name jwt-lab --config kind-cluster.yaml

# Build the Docker image
docker build -t jwt-demo-app:dev .

# Load the image into the kind cluster
kind load docker-image jwt-demo-app:dev --name jwt-lab

# Deploy the app with Helm
helm upgrade --install jwt-demo-app ./helm/jwt-demo-app -n demo --create-namespace \
  --set image.repository=jwt-demo-app --set image.tag=dev
```

Test the endpoints:

```bash
curl http://localhost:3000/public
```
- Should return 200 OK without authentication.

```bash
curl -i http://localhost:3000/private
```
- Should return 401 Unauthorized because no token is provided.

```bash
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJmb28iOiJiYXIifQ.c2ln" http://localhost:3000/private
```
- Attempts to access private route with a token.

Clean up manually:

```bash
helm uninstall jwt-demo-app -n demo || true
kubectl delete ns demo --ignore-not-found
kind delete cluster --name jwt-lab || true
```

**Why this scenario matters:**

Running the app inside Kubernetes is closer to how apps run in production. It familiarizes you with cluster management, deploying apps with Helm, and image handling in Kubernetes.

---

### Scenario 3: Run the App in Kubernetes with Istio (JWT Enforced at the Mesh)

This is the most advanced setup, where Istio enforces JWT authentication at the network mesh level.

#### Using Makefile (Automated)

Start by creating the cluster and deploying the app:

```bash
make kind-up
make k8s-kind-deploy
```

Install Istio and enable sidecar injection:

```bash
make istio-install
make istio-enable-injection
kubectl -n demo rollout restart deploy/jwt-demo-app
kubectl -n demo rollout status deploy/jwt-demo-app
```

Generate JWKS and a test JWT token:

```bash
ISSUER="https://demo-issuer.local" KID="demo-kid" scripts/gen-rs256.sh
```

Deploy Istio Gateway and JWT policies:

```bash
ISSUER="https://demo-issuer.local" make istio-auth-deploy
```

Expose Istio Ingress Gateway as NodePort:

```bash
make istio-expose
```

Allow public endpoints:

```bash
make istio-allow-public
```

Test the app via Istio Ingress Gateway with the `Host` header set to `demo.localhost`:

```bash
# Public endpoint (no token required)
curl -H "Host: demo.localhost" http://localhost:8080/public
```

```bash
# private (no token) → 403 Forbidden (RBAC: access denied from Istio)
curl -i -H "Host: demo.localhost" http://localhost:8080/private
```

```bash
# Private endpoint with token - should return 200 OK with JSON payload
TOKEN=$(cat token.txt)
curl -H "Host: demo.localhost" -H "Authorization: Bearer $TOKEN" http://localhost:8080/private
```

Clean up the environment:

```bash
make istio-delete
make k8s-kind-delete
make kind-down
rm -rf .keys jwks.json token.txt
```

#### Command reference (what each does)

- `make kind-up` — Creates a local kind cluster named **jwt-lab** using `kind-cluster.yaml` (includes host port mappings like 8080→30080).
- `make k8s-kind-deploy` — Builds the app image, loads it into kind, and `helm upgrade --install` the app chart into the **demo** namespace.
- `make istio-install` — Installs Istio (demo profile) into the cluster using `istioctl`.
- `make istio-enable-injection` — Labels the **demo** namespace for automatic sidecar injection and restarts the Deployment so pods get Envoy.
- `ISSUER="..." KID="..." scripts/gen-rs256.sh` — Generates RSA keys, writes **jwks.json**, and creates a signed **token.txt** (RS256) for testing.
- `ISSUER="..." make istio-auth-deploy` — Deploys the Istio Gateway, VirtualService, JWT **RequestAuthentication** (with your issuer + jwks), and **AuthorizationPolicy**; also configures forwarding of the original Authorization header.
- `make istio-expose` — Patches the Istio ingress Service to **NodePort 30080** so it’s reachable on host **localhost:8080** via kind’s port mapping.
- `make istio-allow-public` — Applies an AuthorizationPolicy that allows **/**, **/public\***, and **/favicon.ico** without a token.
- `curl -H "Host: demo.localhost" ...` — Sends traffic through the Istio Ingress by setting the virtual **Host**; required for the Gateway/VirtualService to match.
- `make istio-delete` — Removes the Istio auth resources and uninstalls the Istio control plane.
- `make k8s-kind-delete` — Uninstalls the app release and deletes the **demo** namespace.
- `make kind-down` — Deletes the kind cluster and its Docker node.
- `rm -rf .keys jwks.json token.txt` — Deletes locally generated keys, JWKS, and test token to clean your workspace.

#### Manual Steps

If you want to perform the steps manually:

```bash
# Create the cluster and deploy the app
kind create cluster --name jwt-lab --config kind-cluster.yaml
docker build -t jwt-demo-app:dev .
kind load docker-image jwt-demo-app:dev --name jwt-lab
helm upgrade --install jwt-demo-app ./helm/jwt-demo-app -n demo --create-namespace \
  --set image.repository=jwt-demo-app --set image.tag=dev
```

Install Istio:

```bash
istioctl install --set profile=demo -y
kubectl label namespace demo istio-injection=enabled --overwrite
kubectl -n demo rollout restart deploy/jwt-demo-app
kubectl -n demo rollout status deploy/jwt-demo-app
```

Generate JWKS and token:

```bash
ISSUER="https://demo-issuer.local" KID="demo-kid" scripts/gen-rs256.sh
```

Deploy Istio Gateway and JWT policies:

Helm templates contain Go templating and can't be kubectl-applied directly. Render them first, then apply:

```bash
helm template istio-auth ./helm/istio-auth -n demo \
  --set host=demo.localhost \
  --set issuer="https://demo-issuer.local" \
  --set-file jwks=./jwks.json \
  --set forwardOriginalToken=true \
| kubectl apply -f -
```

Expose Istio ingress gateway as NodePort:

```bash
# Expose Istio ingress gateway on NodePort 30080 (matches kind hostPort 8080 mapping)
kubectl -n istio-system patch svc istio-ingressgateway \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"http2","port":80,"nodePort":30080}]}}'
```

We set the NodePort explicitly so it always matches kind’s hostPort 8080 → nodePort 30080 mapping.

Allow public endpoints by applying the public AuthorizationPolicy:

```bash
kubectl apply -n demo -f helm/istio-auth/templates/authorizationpolicy-public.yaml
```

Test the app via Istio ingress gateway:

```bash
# Public endpoint (no token required)
curl -H "Host: demo.localhost" http://localhost:8080/public
```

```bash
# Private endpoint without token → 403 Forbidden (RBAC: access denied from Istio)
curl -i -H "Host: demo.localhost" http://localhost:8080/private
```

```bash
# Private endpoint with token - should return 200 OK with JSON payload
TOKEN=$(cat token.txt)
curl -H "Host: demo.localhost" -H "Authorization: Bearer $TOKEN" http://localhost:8080/private
```

Clean up manually:

```bash
# Delete Istio auth resources (by name)
kubectl -n demo delete gateway jwt-demo-gw || true
kubectl -n demo delete virtualservice jwt-demo-vs || true
kubectl -n demo delete requestauthentication jwt-demo-reqauth || true
kubectl -n demo delete authorizationpolicy jwt-demo-authz jwt-demo-allow-public || true
kubectl -n istio-system delete requestauthentication jwt-demo-reqauth-gw || true

# Remove app + namespace + cluster
helm uninstall jwt-demo-app -n demo || true
kubectl delete ns demo --ignore-not-found
kind delete cluster --name jwt-lab || true
rm -rf .keys jwks.json token.txt
```

**Why this scenario matters:**

This scenario demonstrates how Istio can enforce security policies at the network layer, validating JWT tokens before allowing access to private routes.

---

## 3) Troubleshooting

If you encounter issues, here are some helpful commands and explanations:

- **Check pods in the `demo` namespace:**

```bash
kubectl -n demo get pods -o wide
```
Shows the status and details of pods, helping identify if any pods failed to start.

- **Describe the deployment:**

```bash
kubectl -n demo describe deploy jwt-demo-app
```
Provides detailed information about the deployment, including events and errors.

- **View logs of the Istio sidecar proxy:**

```bash
kubectl -n demo logs deploy/jwt-demo-app -c istio-proxy
```
Shows logs from the Envoy proxy sidecar, useful for debugging Istio-related issues.

- **Check Istio authentication and authorization policies:**

```bash
kubectl -n demo get requestauthentication,authorizationpolicy
```
Lists the JWT and authorization policies applied in the namespace.

- **Get Istio ingress gateway service details:**

```bash
kubectl -n istio-system get svc istio-ingressgateway
```
Shows how the ingress gateway is exposed.

### Common Issues Explained:

- **No sidecar injected:**
  Make sure the namespace is labeled for automatic sidecar injection (`istio-injection=enabled`). Restart deployments after labeling.

- **401 Unauthorized with valid token:**
  This usually means the issuer URL or JWKS key ID (`kid`) in the Istio configuration does not match the token.

- **404 Not Found at the gateway:**
  Ensure you are sending the correct `Host` header (`demo.localhost`) in your requests, as Istio routes traffic based on hostname.

---

## 4) Appendix — Endpoints Explained

- `GET /public`
  - Always returns HTTP 200 OK. No authentication required.
  - Useful for public content or health checks.

- `GET /private`
  - Returns HTTP 200 OK only if a valid JWT token is presented **and** Istio policies are applied.
  - Otherwise, returns HTTP 401 Unauthorized.
  - Demonstrates how to protect sensitive routes.

---

## 5) Deep Dive into Helm Charts and Templates

In this section, we'll explore what the Helm charts in this project are doing. Helm helps you manage Kubernetes resources in a reusable and configurable way. Understanding these charts will help you see how the app and Istio security features are deployed.

### jwt-demo-app Chart

This chart deploys the Node.js application inside Kubernetes.

- **Deployment:**

  - Runs the Node.js app container.
  - Sets environment variables like `HOST` and `PORT` so the app listens correctly.
  - Exposes container port `3000` where the app serves requests.
  - Includes labels and selectors to manage pods.
  - Configured to restart pods automatically if they fail.

- **Service:**

  - Defines a Kubernetes Service of type `NodePort`.
  - Exposes the app on a port accessible outside the cluster (e.g., on localhost when using kind).
  - Routes traffic to the pods running the app.
  - This allows you to access the app via `localhost:<nodePort>`.

- **values.yaml:**

  - Contains configurable settings such as:
    - `image.repository`: the Docker image repository (default is `jwt-demo-app`).
    - `image.tag`: the image tag/version (default is `dev`).
  - This lets you easily change which image version is deployed without modifying templates.

**Why this matters:**

The `jwt-demo-app` chart packages everything needed to run your Node.js app inside Kubernetes, making deployment consistent and repeatable.

---

### istio-auth Chart

This chart manages Istio resources that enforce JWT authentication and route traffic securely.

- **Gateway:**

  - Acts as the entry point into the Istio service mesh.
  - Configured to listen on specific ports (e.g., HTTP 8080).
  - Routes incoming traffic based on hostnames (e.g., `demo.localhost`).
  - Allows external traffic to reach your services inside the mesh.

- **VirtualService:**

  - Defines how requests are routed within the mesh.
  - Maps host and path combinations (like `/public` or `/private`) to the appropriate Kubernetes Service.
  - Enables advanced routing features like retries, timeouts, and more if needed.

- **RequestAuthentication:**

  - Configures Istio to validate JWT tokens on incoming requests.
  - Specifies the JWKS URI (where public keys are fetched) and the expected issuer.
  - Ensures that only requests with valid JWTs can access protected routes.
  - Istio performs this validation before traffic reaches your app.

- **AuthorizationPolicy:**

  - Defines Role-Based Access Control (RBAC) rules.
  - Allows or denies requests based on JWT claims or other attributes.
  - Used to restrict access to private routes only to authenticated users.
  - Can be fine-tuned to allow public access to certain paths.

- **Additional AuthorizationPolicy for Public Routes:**

  - Specifically allows unauthenticated access to public endpoints like `/public`.
  - Ensures that users don’t need a JWT token to access non-sensitive resources.
  - Provides a clear separation between public and protected content.

**Why this matters:**

The `istio-auth` chart configures Istio to enforce security policies transparently at the network layer. This means your app doesn't need to handle authentication logic itself — Istio does it for you, improving security and simplifying your application code.

---

### Why `requestauth-gw.yaml` (gateway-scoped RequestAuthentication) exists

This project includes a **gateway-scoped** `RequestAuthentication` manifest (named `requestauth-gw.yaml`) that targets the **Istio ingress gateway** pods.

**What it does**
- Installs a **JWT validation filter at the edge** (on the ingress gateway Envoy) using your configured **issuer** and inline **JWKS**.
- With `forwardOriginalToken: true`, it **preserves the `Authorization: Bearer <JWT>` header** after validation so the token is still present when the request reaches the backend service (letting your app display claims).

**Why it targets `istio: ingressgateway`**
- The ingress gateway Deployment/Pods in the `istio-system` namespace are labeled `istio: ingressgateway`.
- Selecting this label ensures the JWT filter is applied **on the gateway** (not just on the workload pods), establishing a strong **edge security boundary**.

**Why the demo won’t work as designed without it**
- The learning goal is twofold: (1) **Istio enforces auth** for `/private`, and (2) the **app can show decoded claims** from the same JWT.
- If JWT validation only happens at the workload, or if any hop drops the header after verification, the **Authorization header won’t reach the app**, so `/private` can’t show claims.
- By validating **at the gateway** and **forwarding the original token**, we both secure the edge and enable the app to present the token’s claims — which is the key teaching outcome of this lab.