import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

type CleanupRow = {
  id: string;
  publication_id: string;
  storage_bucket: string;
  storage_path: string;
  attempts: number;
  claim_token: string;
};

type RequestBody = {
  mode?: unknown;
};

const managedBucket = "institutional-publications";
const batchLimit = 20;

function respond(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return Response.json(body, {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

function validUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
      .test(value);
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return respond({ error: "Method not allowed." }, 405);
    }

    const { data: authData, error: authError } = await ctx.supabase.auth
      .getUser();

    if (authError || !authData.user?.id) {
      return respond(
        { error: "Authentication required." },
        401,
      );
    }

    const { data: profile, error: profileError } = await ctx.supabase
      .from("profiles")
      .select("role, active, staff_approval_pending")
      .eq("id", authData.user.id)
      .maybeSingle();

    if (profileError) {
      return respond(
        { error: "Could not validate permissions." },
        500,
      );
    }

    if (
      !profile ||
      profile.active !== true ||
      !["admin", "superAdmin"].includes(profile.role)
    ) {
      return respond(
        { error: "Administrator permissions are required." },
        403,
      );
    }

    if (profile.staff_approval_pending !== false) {
      return respond(
        { error: "Institutional staff approval is required." },
        403,
      );
    }

    let body: RequestBody;

    try {
      body = (await req.json()) as RequestBody;
    } catch {
      return respond({ error: "Valid JSON is required." }, 400);
    }

    const mode = body?.mode ?? "status";

    if (mode !== "status" && mode !== "process") {
      return respond(
        { error: "Invalid mode. Use status or process." },
        400,
      );
    }

    // Physical deletion is deliberately disabled by default.
    const enabled = Deno.env.get("ENABLE_PUBLICATION_ASSET_CLEANUP") ===
      "true";

    if (mode === "status") {
      return respond({
        service: "cleanup-publication-assets",
        authenticated: true,
        enabled,
        physical_deletion_enabled: enabled,
        batch_limit: batchLimit,
      });
    }

    if (!enabled) {
      return respond({
        error: "Physical cleanup is not enabled.",
        code: "CLEANUP_DISABLED",
        processed: 0,
      }, 503);
    }

    // CAUTION:
    // Do not enable this worker until both cleanup queues,
    // concurrent reference writes, and Storage policies
    // have passed the remaining integration tests.

    const { data: claimed, error: claimError } = await ctx.supabaseAdmin.rpc(
      "claim_publication_asset_cleanup",
      { p_limit: batchLimit },
    );

    if (claimError) {
      return respond({
        error: "Could not claim cleanup work.",
        code: claimError.code,
      }, 500);
    }

    const queue = (claimed ?? []) as CleanupRow[];

    let cleaned = 0;
    let failed = 0;

    for (const item of queue) {
      let success = false;
      let errorMessage: string | null = null;

      const validReference = validUuid(item.id) &&
        validUuid(item.publication_id) &&
        validUuid(item.claim_token) &&
        item.storage_bucket === managedBucket &&
        typeof item.storage_path === "string" &&
        item.storage_path.startsWith(
          `${item.publication_id}/`,
        ) &&
        item.storage_path.length >
          item.publication_id.length + 1;

      if (!validReference) {
        errorMessage = "Invalid managed Storage reference.";
      } else {
        try {
          const { error: storageError } = await ctx.supabaseAdmin.storage
            .from(managedBucket)
            .remove([item.storage_path]);

          if (storageError) {
            errorMessage = storageError.message;
          } else {
            success = true;
          }
        } catch {
          errorMessage = "Storage cleanup request failed.";
        }
      }

      if (!validUuid(item.id) || !validUuid(item.claim_token)) {
        failed++;
        continue;
      }

      const { data: finished, error: finishError } = await ctx.supabaseAdmin
        .rpc(
          "finish_publication_asset_cleanup",
          {
            p_id: item.id,
            p_claim_token: item.claim_token,
            p_success: success,
            p_error: errorMessage,
          },
        );

      if (finishError || finished !== true) {
        // Work can be reclaimed after its lease expires.
        failed++;
        continue;
      }

      if (success) {
        cleaned++;
      } else {
        failed++;
      }
    }

    return respond({
      processed: queue.length,
      cleaned,
      failed,
      physical_deletion_enabled: true,
      retry_required: failed > 0,
    }, failed > 0 ? 207 : 200);
  }),
};
