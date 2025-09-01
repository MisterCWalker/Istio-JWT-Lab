#!/usr/bin/env bash
set -euo pipefail
ISSUER="${ISSUER:-https://demo-issuer.local}"
KID="${KID:-demo-kid}"

# Ensure deps present (uses local package.json dependency on jose)
if ! node -e "require.resolve('jose')" >/dev/null 2>&1; then
  echo "==> Installing jose (local)"
  npm install --no-save jose@5.9.3 >/dev/null 2>&1
fi

mkdir -p .keys

echo "==> Generating RSA keypair"
openssl genrsa -out .keys/rs256.key 2048 >/dev/null 2>&1
openssl rsa -in .keys/rs256.key -pubout -out .keys/rs256.pub >/dev/null 2>&1

echo "==> Writing JWKS (jwks.json)"
node --input-type=module -e '
  import {importSPKI, exportJWK} from "jose";
  import fs from "node:fs";
  const spki = fs.readFileSync(".keys/rs256.pub","utf8");
  const kid = process.env.KID;
  const key = await importSPKI(spki,"RS256");
  const jwk = await exportJWK(key);
  jwk.kid = kid; jwk.alg = "RS256"; jwk.use = "sig";
  const jwks = { keys: [jwk] };
  fs.writeFileSync("jwks.json", JSON.stringify(jwks, null, 2));
'

echo "==> Generating JWT (token.txt)"
node --input-type=module -e '
  import {SignJWT, importPKCS8} from "jose";
  import fs from "node:fs";
  const pkcs8 = fs.readFileSync(".keys/rs256.key", "utf8");
  const kid = process.env.KID, iss = process.env.ISSUER;
  const key = await importPKCS8(pkcs8, "RS256");
  const jwt = await new SignJWT({ sub: "demo-user", role: "tester" })
    .setProtectedHeader({ alg: "RS256", kid })
    .setIssuer(iss).setAudience("demo").setIssuedAt().setExpirationTime("15m")
    .sign(key);
  fs.writeFileSync("token.txt", jwt);
  console.log(jwt);
'

echo "==> Done. Files: jwks.json and token.txt"