import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { GoogleAuth } from "google-auth-library";

const firebaseProjectId = "conecta-itt-55275";
const firebaseMessagingScope =
  "https://www.googleapis.com/auth/firebase.messaging";

type RequestBody = {
  announcement_id?: unknown;
};

type AnnouncementResults = {
  announcement_id: string;
  title: string;
  status: string;
  content_type: "announcement" | "news";
  content_version: number;
  recipients: Array<{
    user_id: string;
  }>;
};

type FcmTokenRow = {
  id: string;
  user_id: string;
  token: string;
  platform: string | null;
};

type PublicationCoverRow = {
  storage_bucket: string;
  storage_path: string;
};

type SendResult = {
  tokenId: string;
  userId: string;
  success: boolean;
  invalidToken: boolean;
  error?: string;
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

function readServiceAccount(): Record<string, unknown> {
  const encoded = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_BASE64");

  if (!encoded) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_BASE64 is not configured.");
  }

  try {
    const decoded = atob(encoded);
    return JSON.parse(decoded) as Record<string, unknown>;
  } catch {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_BASE64 is not valid base64 JSON.",
    );
  }
}

async function getFirebaseAccessToken(): Promise<string> {
  const credentials = readServiceAccount();

  const auth = new GoogleAuth({
    credentials,
    scopes: [firebaseMessagingScope],
  });

  const client = await auth.getClient();
  const accessToken = await client.getAccessToken();

  if (!accessToken.token) {
    throw new Error("Google OAuth did not return an access token.");
  }

  return accessToken.token;
}

function notificationBody(results: AnnouncementResults): string {
  if (results.content_type === "news") {
    return results.title.length <= 120
      ? "Tienes una nueva noticia institucional."
      : "Consulta la nueva noticia institucional en Conecta ITT.";
  }

  return results.title.length <= 120
    ? "Tienes un nuevo comunicado institucional."
    : "Consulta el nuevo comunicado institucional en Conecta ITT.";
}

function isInvalidFcmToken(
  status: number,
  responseBody: Record<string, unknown>,
): boolean {
  if (status === 404) {
    return true;
  }

  const error = responseBody.error;

  if (!error || typeof error !== "object") {
    return false;
  }

  const details = (error as { details?: unknown }).details;

  if (!Array.isArray(details)) {
    return false;
  }

  return details.some((detail) => {
    if (!detail || typeof detail !== "object") {
      return false;
    }

    const errorCode = (detail as { errorCode?: unknown }).errorCode;

    return errorCode === "UNREGISTERED";
  });
}

async function resolveCoverImageUrl({
  announcementId,
  supabaseAdmin,
}: {
  announcementId: string;
  supabaseAdmin: {
    from: (table: string) => any;
    storage: {
      from: (bucket: string) => {
        createSignedUrl: (
          path: string,
          expiresIn: number,
        ) => Promise<{
          data: { signedUrl?: string } | null;
          error: { message: string } | null;
        }>;
      };
    };
  };
}): Promise<string | null> {
  const { data: coverData, error: coverError } = await supabaseAdmin
    .from("publication_assets")
    .select("storage_bucket, storage_path")
    .eq("publication_id", announcementId)
    .eq("asset_type", "cover")
    .maybeSingle();

  if (coverError) {
    console.warn(
      `Could not resolve notification cover metadata: ${coverError.message}`,
    );
    return null;
  }

  if (!coverData) {
    return null;
  }

  const cover = coverData as PublicationCoverRow;

  if (!cover.storage_bucket || !cover.storage_path) {
    return null;
  }

  const { data: signedUrlData, error: signedUrlError } =
    await supabaseAdmin.storage
      .from(cover.storage_bucket)
      .createSignedUrl(cover.storage_path, 24 * 60 * 60);

  if (signedUrlError) {
    console.warn(
      `Could not create notification cover URL: ${signedUrlError.message}`,
    );
    return null;
  }

  const signedUrl = signedUrlData?.signedUrl?.trim();

  return signedUrl && signedUrl.length > 0 ? signedUrl : null;
}

async function sendToToken({
  accessToken,
  announcement,
  imageUrl,
  token,
}: {
  accessToken: string;
  announcement: AnnouncementResults;
  imageUrl: string | null;
  token: FcmTokenRow;
}): Promise<SendResult> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: token.token,
          notification: {
            title: announcement.title,
            body: notificationBody(announcement),
          },
          data: {
            type: "institutional_announcement",
            content_type: announcement.content_type,
            announcement_id: announcement.announcement_id,
            content_version: String(announcement.content_version),
            ...(imageUrl ? { image_url: imageUrl } : {}),
          },
          android: {
            priority: "high",
            notification: {
              channel_id: "institutional_announcements",
              sound: "default",
              ...(imageUrl ? { image: imageUrl } : {}),
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                sound: "default",
                "content-available": 1,
              },
            },
          },
        },
      }),
    },
  );

  let responseBody: Record<string, unknown> = {};

  try {
    responseBody = (await response.json()) as Record<string, unknown>;
  } catch {
    responseBody = {};
  }

  if (response.ok) {
    return {
      tokenId: token.id,
      userId: token.user_id,
      success: true,
      invalidToken: false,
    };
  }

  return {
    tokenId: token.id,
    userId: token.user_id,
    success: false,
    invalidToken: isInvalidFcmToken(response.status, responseBody),
    error: JSON.stringify(responseBody),
  };
}

async function sendInChunks({
  accessToken,
  announcement,
  imageUrl,
  tokens,
}: {
  accessToken: string;
  announcement: AnnouncementResults;
  imageUrl: string | null;
  tokens: FcmTokenRow[];
}): Promise<SendResult[]> {
  const results: SendResult[] = [];
  const chunkSize = 20;

  for (let index = 0; index < tokens.length; index += chunkSize) {
    const chunk = tokens.slice(index, index + chunkSize);

    const chunkResults = await Promise.all(
      chunk.map((token) =>
        sendToToken({
          accessToken,
          announcement,
          imageUrl,
          token,
        }),
      ),
    );

    results.push(...chunkResults);
  }

  return results;
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Method not allowed." }, 405);
    }

    const { data: authenticatedUserData, error: authenticatedUserError } =
      await ctx.supabase.auth.getUser();

    if (authenticatedUserError) {
      return jsonResponse(
        {
          error: "Could not validate the authenticated user.",
          details: authenticatedUserError.message,
        },
        401,
      );
    }

    const callerId = authenticatedUserData.user?.id;

    if (!callerId) {
      return jsonResponse(
        { error: "Authenticated user identifier is missing." },
        401,
      );
    }

    let requestBody: RequestBody;

    try {
      requestBody = (await req.json()) as RequestBody;
    } catch {
      return jsonResponse({ error: "A valid JSON body is required." }, 400);
    }

    const announcementId = requestBody.announcement_id;

    if (
      typeof announcementId !== "string" ||
      announcementId.trim().length === 0
    ) {
      return jsonResponse({ error: "announcement_id is required." }, 400);
    }

    const { data: callerProfile, error: callerProfileError } =
      await ctx.supabase
        .from("profiles")
        .select("id, role, active")
        .eq("id", callerId)
        .maybeSingle();

    if (callerProfileError) {
      return jsonResponse(
        {
          error: "Could not validate the caller profile.",
          details: callerProfileError.message,
        },
        500,
      );
    }

    if (
      !callerProfile ||
      callerProfile.active !== true ||
      !["admin", "superAdmin"].includes(callerProfile.role)
    ) {
      return jsonResponse(
        { error: "Administrator permissions are required." },
        403,
      );
    }

    const { data: announcementResults, error: announcementResultsError } =
      await ctx.supabase.rpc("get_announcement_results", {
        p_announcement_id: announcementId,
      });

    if (announcementResultsError) {
      return jsonResponse(
        {
          error: "Could not resolve the announcement audience.",
          details: announcementResultsError.message,
        },
        400,
      );
    }

    const announcement = announcementResults as AnnouncementResults;

    if (announcement.status !== "published") {
      return jsonResponse(
        {
          error: "Only published institutional publications can send notifications.",
        },
        409,
      );
    }

    const { data: dispatch, error: dispatchError } = await ctx.supabaseAdmin
      .from("announcement_notification_dispatches")
      .insert({
        announcement_id: announcement.announcement_id,
        content_version: announcement.content_version,
        requested_by: callerId,
        status: "processing",
        audience_count: announcement.recipients.length,
      })
      .select("id")
      .single();

    if (dispatchError) {
      if (dispatchError.code === "23505") {
        return jsonResponse(
          {
            error:
              "A notification was already sent or started for this announcement version.",
            duplicate: true,
          },
          409,
        );
      }

      return jsonResponse(
        {
          error: "Could not reserve the notification dispatch.",
          details: dispatchError.message,
        },
        500,
      );
    }

    const dispatchId = dispatch.id as string;

    try {
      const recipientIds = [
        ...new Set(
          announcement.recipients.map((recipient) => recipient.user_id),
        ),
      ];

      if (recipientIds.length === 0) {
        await ctx.supabaseAdmin
          .from("announcement_notification_dispatches")
          .update({
            status: "completed",
            completed_at: new Date().toISOString(),
          })
          .eq("id", dispatchId);

        return jsonResponse({
          dispatch_id: dispatchId,
          audience_count: 0,
          token_count: 0,
          sent_count: 0,
          failed_count: 0,
          no_token_count: 0,
          invalid_token_count: 0,
        });
      }

      const { data: tokenRows, error: tokenRowsError } = await ctx.supabaseAdmin
        .from("user_fcm_tokens")
        .select("id, user_id, token, platform")
        .in("user_id", recipientIds)
        .eq("active", true);

      if (tokenRowsError) {
        throw new Error(tokenRowsError.message);
      }

      const tokens = (tokenRows ?? []) as FcmTokenRow[];
      const usersWithTokens = new Set(tokens.map((token) => token.user_id));

      const noTokenCount = recipientIds.filter(
        (userId) => !usersWithTokens.has(userId),
      ).length;

      const imageUrl = await resolveCoverImageUrl({
        announcementId: announcement.announcement_id,
        supabaseAdmin: ctx.supabaseAdmin,
      });

      const accessToken = await getFirebaseAccessToken();

      const sendResults = await sendInChunks({
        accessToken,
        announcement,
        imageUrl,
        tokens,
      });

      const successfulResults = sendResults.filter((result) => result.success);

      const failedResults = sendResults.filter((result) => !result.success);

      const invalidResults = failedResults.filter(
        (result) => result.invalidToken,
      );

      if (invalidResults.length > 0) {
        await ctx.supabaseAdmin
          .from("user_fcm_tokens")
          .update({
            active: false,
            updated_at: new Date().toISOString(),
          })
          .in(
            "id",
            invalidResults.map((result) => result.tokenId),
          );
      }

      await ctx.supabaseAdmin
        .from("announcement_notification_dispatches")
        .update({
          status: "completed",
          token_count: tokens.length,
          sent_count: successfulResults.length,
          failed_count: failedResults.length,
          no_token_count: noTokenCount,
          invalid_token_count: invalidResults.length,
          completed_at: new Date().toISOString(),
        })
        .eq("id", dispatchId);

      return jsonResponse({
        dispatch_id: dispatchId,
        announcement_id: announcement.announcement_id,
        content_version: announcement.content_version,
        audience_count: recipientIds.length,
        token_count: tokens.length,
        sent_count: successfulResults.length,
        failed_count: failedResults.length,
        no_token_count: noTokenCount,
        invalid_token_count: invalidResults.length,
        has_cover_image: imageUrl != null,
      });
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : "Unknown notification dispatch error.";

      await ctx.supabaseAdmin
        .from("announcement_notification_dispatches")
        .update({
          status: "failed",
          error_message: message,
          completed_at: new Date().toISOString(),
        })
        .eq("id", dispatchId);

      return jsonResponse(
        {
          error: "The notification dispatch failed.",
          details: message,
          dispatch_id: dispatchId,
        },
        500,
      );
    }
  }),
};
