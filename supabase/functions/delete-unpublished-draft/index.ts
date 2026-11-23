import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

type RequestBody = {
  publication_id?: unknown;
};

type CleanupRow = {
  id: string;
  storage_bucket: string;
  storage_path: string;
  attempts: number;
  claim_token: string;
};

const managedBucket = "institutional-publications";
const batchLimit = 20;

function respond(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return Response.json(body, {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return respond({ error: "Method not allowed." }, 405);
    }

    const { data: authData, error: authError } = await ctx.supabase.auth
      .getUser();

    if (authError || !authData.user?.id) {
      return respond({ error: "Authentication required." }, 401);
    }

    const userId = authData.user.id;

    const { data: profile, error: profileError } = await ctx.supabase
      .from("profiles")
      .select("role, active, staff_approval_pending")
      .eq("id", userId)
      .maybeSingle();

    if (profileError) {
      return respond(
        { error: "Could not validate administrator permissions." },
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

    const publicationId = body?.publication_id;

    if (
      typeof publicationId !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
        .test(publicationId)
    ) {
      return respond({ error: "Valid publication_id required." }, 400);
    }

    // The user-scoped RPC enforces all database deletion conditions.
    let deletedNow = false;

    const { data: deletion, error: deletionError } = await ctx.supabase.rpc(
      "delete_unpublished_draft",
      {
        p_publication_id: publicationId,
      },
    );

    if (deletionError) {
      const previouslyDeleted = deletionError.code === "P0002" &&
        deletionError.message.includes("Publication not found");

      // Only an already-deleted publication may resume cleanup.
      if (!previouslyDeleted) {
        return respond({
          error: "Draft deletion was rejected.",
          code: deletionError.code,
          message: deletionError.message,
        }, 409);
      }
    } else {
      deletedNow = deletion?.deleted === true;

      if (!deletedNow) {
        return respond(
          { error: "Deletion was not confirmed." },
          500,
        );
      }
    }

    // A missing publication may only resume a recorded cleanup.
    if (!deletedNow) {
      const { count, error: historyError } = await ctx.supabaseAdmin
        .from("draft_publication_storage_cleanup")
        .select("id", { count: "exact", head: true })
        .eq("publication_id", publicationId);

      if (historyError) {
        return respond({
          deleted: false,
          storage_cleanup_complete: false,
          error: "Could not verify previous cleanup.",
        }, 500);
      }

      if (!count) {
        return respond({
          error: "No authorized cleanup record exists.",
        }, 404);
      }
    }

    // PostgreSQL atomically reserves each object for one worker.
    const { data: claimed, error: claimError } = await ctx.supabaseAdmin.rpc(
      "claim_draft_storage_cleanup",
      {
        p_publication_id: publicationId,
        p_limit: batchLimit,
      },
    );

    if (claimError) {
      return respond({
        deleted: deletedNow,
        storage_cleanup_complete: false,
        error: "Could not reserve Storage cleanup work.",
      }, 500);
    }

    const queue = (claimed ?? []) as CleanupRow[];
    let cleaned = 0;
    let failed = 0;

    for (const item of queue) {
      let success = false;
      let errorMessage: string | null = null;

      if (
        item.storage_bucket !== managedBucket ||
        !item.storage_path ||
        !item.claim_token
      ) {
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

      if (!item.claim_token) {
        failed++;
        continue;
      }

      const { data: finished, error: finishError } = await ctx.supabaseAdmin
        .rpc(
          "finish_draft_storage_cleanup",
          {
            p_id: item.id,
            p_claim_token: item.claim_token,
            p_success: success,
            p_error: errorMessage,
          },
        );

      if (finishError || finished !== true) {
        // A processing record remains recoverable after its lease expires.
        failed++;
        continue;
      }

      if (success) {
        cleaned++;
      } else {
        failed++;
      }
    }

    // Include files reserved by another concurrent request.
    const { count: remaining, error: remainingError } = await ctx.supabaseAdmin
      .from("draft_publication_storage_cleanup")
      .select("id", { count: "exact", head: true })
      .eq("publication_id", publicationId)
      .neq("status", "completed");

    if (remainingError) {
      return respond({
        deleted: deletedNow,
        cleaned,
        storage_cleanup_complete: false,
        error: "Could not confirm remaining cleanup work.",
      }, 500);
    }

    const pending = remaining ?? 0;
    const complete = pending === 0 && failed === 0;

    return respond({
      publication_id: publicationId,
      deleted: deletedNow,
      cleaned,
      failed,
      pending,
      storage_cleanup_complete: complete,
      retry_required: pending > 0,
    }, complete ? 200 : 207);
  }),
};
