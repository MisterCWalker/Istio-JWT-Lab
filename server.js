import express from "express";

const app = express();
const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || "0.0.0.0";

// simple liveness route
app.get("/", (_req, res) => res.status(200).send("ok"));

app.get("/public", (_req, res) => {
  res.status(200).send("hey this is publicly accessible and has no auth");
});

function b64urlDecode(s) {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/");
  const pad = b64.length % 4 === 2 ? "==" : b64.length % 4 === 3 ? "=" : "";
  return Buffer.from(b64 + pad, "base64").toString("utf8");
}
function decodeJwtUnsafe(token) {
  const parts = token.split(".");
  if (parts.length < 2) throw new Error("malformed");
  return JSON.parse(b64urlDecode(parts[1]));
}

app.get("/private", (req, res) => {
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;

  if (!token) {
    return res
      .status(401)
      .send('hey, this is private and needed auth (send Authorization: Bearer <JWT>)');
  }

  try {
    // decode only; verification is expected upstream (e.g., Istio)
    const payload = decodeJwtUnsafe(token);
    res.status(200).json({
      message: "hey, this is private and needed auth, here is your JWT info",
      jwt: payload,
    });
  } catch {
    res.status(400).send("invalid JWT format");
  }
});

app.listen(PORT, HOST, () => {
  console.log(`listening on ${HOST}:${PORT}`);
});