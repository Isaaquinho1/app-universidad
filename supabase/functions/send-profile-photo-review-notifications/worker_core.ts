/// Transport-independent photograph notification worker.
/// The actual Supabase and Firebase operations are injected.

export type PhotoTask = {
  id: string;
  submission_id: string;
  student_id: string;
  decision: "approved" | "rejected";
  claim_token: string;
};

export type DeviceToken = {
  id: string;
  user_id: string;
  token: string;
  platform: string | null;
};

export type DeviceDelivery = {
  tokenId: string;
  success: boolean;
  invalid: boolean;
};

export type WorkerDependencies = {
  getTokens: (studentId: string) => Promise<DeviceToken[]>;
  getAccessToken: () => Promise<string>;
  send: (
    accessToken: string,
    task: PhotoTask,
    token: DeviceToken,
  ) => Promise<DeviceDelivery>;
  deactivateInvalid: (
    studentId: string,
    tokenIds: string[],
  ) => Promise<void>;
  complete: (
    taskId: string,
    claimToken: string,
    success: boolean,
    error: string | null,
  ) => Promise<boolean>;
};

export type TaskResult = {
  sent: boolean;
  failed: boolean;
  noTokens: boolean;
  invalidTokens: number;
};

export async function processPhotoNotification(
  task: PhotoTask,
  dependencies: WorkerDependencies,
): Promise<TaskResult> {
  let success = false;
  let reason = "No active device tokens";
  let noTokens = false;
  let invalidTokens = 0;

  try {
    const tokens = await dependencies.getTokens(task.student_id);

    if (tokens.length === 0) {
      noTokens = true;
    } else {
      const accessToken = await dependencies.getAccessToken();
      const deliveries: DeviceDelivery[] = [];

      for (let index = 0; index < tokens.length; index += 20) {
        const chunk = tokens.slice(index, index + 20);

        const results = await Promise.all(
          chunk.map((token) => dependencies.send(accessToken, task, token)),
        );

        deliveries.push(...results);
      }

      const invalidIds = [
        ...new Set(
          deliveries
            .filter((delivery) => delivery.invalid)
            .map((delivery) => delivery.tokenId),
        ),
      ];

      invalidTokens = invalidIds.length;

      if (invalidIds.length > 0) {
        try {
          await dependencies.deactivateInvalid(
            task.student_id,
            invalidIds,
          );
        } catch {
          // Token maintenance must not overwrite delivery results.
        }
      }

      success = deliveries.some((delivery) => delivery.success);
      reason = "All device deliveries failed";
    }
  } catch {
    success = false;
    reason = "Notification transport or configuration failure";
  }

  // Recording failure never changes the underlying photo decision.
  let completed = false;

  try {
    completed = await dependencies.complete(
      task.id,
      task.claim_token,
      success,
      success ? null : reason,
    );
  } catch {
    completed = false;
  }

  // An uncompleted lease may be recovered by PostgreSQL.
  return {
    sent: completed && success,
    failed: !completed || !success,
    noTokens,
    invalidTokens,
  };
}
