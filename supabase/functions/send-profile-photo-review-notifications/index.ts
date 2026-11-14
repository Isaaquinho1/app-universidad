import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { GoogleAuth } from "google-auth-library";
import { processPhotoNotification } from "./worker_core.ts";

const firebaseProjectId = "conecta-itt-55275";
const firebaseScope = "https://www.googleapis.com/auth/firebase.messaging";
const batchLimit = 5;

type NotificationTask = {
  id: string;
  submission_id: string;
  student_id: string;
  decision: "approved" | "rejected";
  claim_token: string;
};

type FcmToken = {
  id: string;
  user_id: string;
  token: string;
  platform: string | null;
};

type Delivery = {
  tokenId: string;
  success: boolean;
  invalid: boolean;
};

function respond(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server configuration: ${name}`);
  return value;
}

async function sameSecret(
  provided: string | null,
  expected: string,
): Promise<boolean> {
  if (!provided || expected.length < 32) return false;

  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(provided)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);

  const left = new Uint8Array(a);
  const right = new Uint8Array(b);
  let difference = 0;

  for (let index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }

  return difference === 0;
}

async function firebaseAccessToken(): Promise<string> {
  const encoded = requiredEnv("FIREBASE_SERVICE_ACCOUNT_BASE64");
  const credentials = JSON.parse(atob(encoded)) as Record<string, unknown>;

  const google = new GoogleAuth({
    credentials,
    scopes: [firebaseScope],
  });

  const client = await google.getClient();
  const result = await client.getAccessToken();

  if (!result.token) {
    throw new Error("Firebase access token unavailable");
  }

  return result.token;
}

function invalidFcmToken(
  status: number,
  body: Record<string, unknown>,
): boolean {
  const error = body.error;

  if (!error || typeof error !== "object") {
    return false;
  }

  const details = (error as { details?: unknown }).details;

  if (Array.isArray(details)) {
    for (const detail of details) {
      if (!detail || typeof detail !== "object") continue;

      const code = (detail as { errorCode?: unknown }).errorCode;

      if (code === "UNREGISTERED") return true;
    }
  }

  return status === 404;
}

export function notificationContent(
  decision: NotificationTask["decision"],
): { title: string; body: string } {
  if (decision === "approved") {
    return {
      title: "Fotografía aprobada",
      body: "Tu fotografía institucional fue aprobada. " +
        "Consulta tu identificación digital en Conecta ITT.",
    };
  }

  return {
    title: "Fotografía rechazada",
    body: "Tu fotografía institucional no fue aprobada. " +
      "Consulta el motivo en tu perfil para enviar otra.",
  };
}

export async function sendToDevice(
  accessToken: string,
  task: NotificationTask,
  token: FcmToken,
  sendRequest: typeof fetch = fetch,
): Promise<Delivery> {
  const content = notificationContent(task.decision);

  try {
    const response = await sendRequest(
      `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
      {
        method: "POST",
        signal: AbortSignal.timeout(15000),
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: token.token,
            notification: content,
            data: {
              type: "profile_photo_review",
              user_id: task.student_id,
              submission_id: task.submission_id,
              notification_id: task.id,
              decision: task.decision,
            },
            android: {
              priority: "high",
              notification: {
                channel_id: "institutional_announcements",
                sound: "default",
              },
            },
            apns: {
              headers: { "apns-priority": "10" },
              payload: {
                aps: { sound: "default" },
              },
            },
          },
        }),
      },
    );

    if (response.ok) {
      return { tokenId: token.id, success: true, invalid: false };
    }

    let body: Record<string, unknown> = {};

    try {
      body = await response.json() as Record<string, unknown>;
    } catch {
      // An unreadable Firebase response is treated as a failed delivery.
    }

    return {
      tokenId: token.id,
      success: false,
      invalid: invalidFcmToken(response.status, body),
    };
  } catch {
    return {
      tokenId: token.id,
      success: false,
      invalid: false,
    };
  }
}

export default {
  async fetch(req: Request): Promise<Response> {
    if (req.method !== "POST") {
      return respond({ error: "Method not allowed" }, 405);
    }

    const workerSecret = Deno.env.get("PHOTO_REVIEW_WORKER_SECRET");

    if (!workerSecret || workerSecret.length < 32) {
      return respond({ error: "Worker not configured" }, 503);
    }

    const authorized = await sameSecret(
      req.headers.get("x-photo-review-worker-secret"),
      workerSecret,
    );

    if (!authorized) {
      return respond({ error: "Unauthorized" }, 401);
    }

    // Safe configuration check: no database RPCs or FCM calls.
    if (req.headers.get("x-photo-review-dry-run") === "true") {
      return respond({
        ok: true,
        dry_run: true,
        queue_processed: false,
        fcm_contacted: false,
      });
    }

    try {
      const supabase = createClient(
        requiredEnv("SUPABASE_URL"),
        requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
        {
          auth: {
            persistSession: false,
            autoRefreshToken: false,
          },
        },
      );

      const { data, error: claimError } = await supabase.rpc(
        "claim_profile_photo_review_notifications",
        { p_limit: batchLimit },
      );

      if (claimError) throw new Error("Could not claim notification tasks");

      const tasks = (data ?? []) as NotificationTask[];

      let sent = 0;
      let failed = 0;
      let noTokens = 0;
      let invalidTokens = 0;

      for (const task of tasks) {
        const result = await processPhotoNotification(task, {
          getTokens: async (studentId) => {
            const { data: tokenData, error: tokenError } = await supabase
              .from("user_fcm_tokens")
              .select("id, user_id, token, platform")
              .eq("user_id", studentId)
              .eq("active", true);

            if (tokenError) {
              throw new Error("Could not load recipient tokens");
            }

            return (tokenData ?? []) as FcmToken[];
          },
          getAccessToken: firebaseAccessToken,
          send: sendToDevice,
          deactivateInvalid: async (studentId, tokenIds) => {
            const { error } = await supabase
              .from("user_fcm_tokens")
              .update({
                active: false,
                updated_at: new Date().toISOString(),
              })
              .in("id", tokenIds)
              .eq("user_id", studentId);

            if (error) {
              throw new Error("Could not deactivate invalid tokens");
            }
          },
          complete: async (id, claimToken, success, errorMessage) => {
            const { data: completed, error } = await supabase.rpc(
              "complete_profile_photo_review_notification",
              {
                p_id: id,
                p_claim_token: claimToken,
                p_success: success,
                p_error: errorMessage,
              },
            );

            return !error && completed === true;
          },
        });

        if (result.sent) sent++;
        if (result.failed) failed++;
        if (result.noTokens) noTokens++;
        invalidTokens += result.invalidTokens;
      }

      return respond({
        ok: true,
        claimed: tasks.length,
        sent,
        failed,
        no_token_tasks: noTokens,
        invalid_tokens: invalidTokens,
      });
    } catch {
      // Do not expose internal credentials or Firebase error details.
      console.error("Photo review notification worker failed");
      return respond({ error: "Notification processing failed" }, 500);
    }
  },
};
