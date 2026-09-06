import { signAppStoreConnectJWT } from "../lib/appstore-jwt.js";
import { ingestSignals } from "../lib/ingest.js";
import type { SignalInput, Severity } from "../types.js";

const APPSTORE_API = "https://api.appstoreconnect.apple.com/v1";

// Week 1 scope: Customer Reviews — a simple, synchronous JSON endpoint that
// serves as a real, working revenue-adjacent health signal (rating trend).
// True Sales/Financial Reports use Apple's async report-request + gzip/TSV
// download flow (request -> poll -> download -> parse) — meaningfully more
// scope than "Week 1 Foundation" and left as a documented Week 2 addition
// (see ganesh-engine/README.md) rather than faked here.
function classifySeverity(rating: number): Severity {
  if (rating <= 1) return "CRITICAL";
  if (rating <= 2) return "WARNING";
  return "INFO";
}

export async function collectAppStore(): Promise<number> {
  const appId = process.env.APPSTORE_APP_ID;
  if (!appId) throw new Error("APPSTORE_APP_ID is not set");

  const token = signAppStoreConnectJWT();
  const params = new URLSearchParams({ sort: "-createdDate", limit: "50" });

  const res = await fetch(`${APPSTORE_API}/apps/${appId}/customerReviews?${params.toString()}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`App Store Connect reviews fetch failed: ${res.status} ${await res.text()}`);
  }

  const data = (await res.json()) as {
    data: Array<{
      id: string;
      attributes: { rating: number; title: string; body: string; createdDate: string; territory: string };
    }>;
  };

  const signals: SignalInput[] = data.data.map((review) => ({
    source: "appstore",
    external_id: review.id,
    event_type: "customer_review",
    severity: classifySeverity(review.attributes.rating),
    payload: {
      rating: review.attributes.rating,
      title: review.attributes.title,
      territory: review.attributes.territory,
      created: review.attributes.createdDate,
    },
  }));

  return ingestSignals(signals);
}
