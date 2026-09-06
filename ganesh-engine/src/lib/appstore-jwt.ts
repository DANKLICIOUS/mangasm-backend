import { createSign } from "node:crypto";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

function base64url(input: Buffer): string {
  return input.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Signs a JWT for the App Store Connect API: ES256 (ECDSA P-256 + SHA-256).
// Node's crypto.sign() defaults to DER-encoded ECDSA signatures, which is
// NOT the raw fixed-length r||s format JOSE/JWT requires — but Node exposes
// `dsaEncoding: "ieee-p1363"` to get that raw format directly, so no manual
// ASN.1 parsing and no external JWT library are needed (constraint 4).
export function signAppStoreConnectJWT(): string {
  const keyId = requireEnv("APPSTORE_CONNECT_KEY_ID");
  const issuerId = requireEnv("APPSTORE_CONNECT_ISSUER_ID");
  const privateKeyPem = requireEnv("APPSTORE_CONNECT_PRIVATE_KEY").replace(/\\n/g, "\n");

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  // Apple caps token lifetime at 20 minutes; 19 stays safely inside it.
  const payload = { iss: issuerId, iat: now, exp: now + 19 * 60, aud: "appstoreconnect-v1" };

  const signingInput =
    `${base64url(Buffer.from(JSON.stringify(header)))}.` +
    `${base64url(Buffer.from(JSON.stringify(payload)))}`;

  const signature = createSign("SHA256")
    .update(signingInput)
    .sign({ key: privateKeyPem, dsaEncoding: "ieee-p1363" });

  return `${signingInput}.${base64url(signature)}`;
}
