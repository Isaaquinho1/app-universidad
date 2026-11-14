import assert from "node:assert/strict";
import pg from "npm:pg@8.16.3";
import { processPhotoNotification } from "./worker_core.ts";

Deno.test("13.7E - trabajador integrado con PostgreSQL local", async (t) => {
  const connectionString = Deno.env.get("PHOTO_REVIEW_TEST_DB_URL");

  if (!connectionString) {
    throw new Error("Falta PHOTO_REVIEW_TEST_DB_URL");
  }

  const address = new URL(connectionString);

  if (
    !["127.0.0.1", "localhost"].includes(address.hostname) ||
    address.pathname !== "/postgres"
  ) {
    throw new Error("SEGURIDAD: solamente se permite PostgreSQL local");
  }

  const client = new pg.Client({
    connectionString,
    ssl: false,
    connectionTimeoutMillis: 5000,
  });

  await client.connect();

  let transactionStarted = false;

  try {
    await client.query("BEGIN");
    transactionStarted = true;

    const existing = await client.query(`
      SELECT count(*)::integer AS total
      FROM public.profile_photo_review_notifications
    `);

    assert.equal(
      existing.rows[0].total,
      0,
      "La cola local debe estar vacía para aislar esta prueba",
    );

    const students = await client.query(`
      SELECT p.id
      FROM public.profiles p
      WHERE NOT EXISTS (
        SELECT 1
        FROM public.student_profile_photo_submissions s
        WHERE s.student_id = p.id AND s.status = 'pending'
      )
      ORDER BY p.created_at
      LIMIT 1
    `);

    const periods = await client.query(`
      SELECT id FROM public.academic_periods LIMIT 1
    `);

    assert.ok(students.rows.length, "Falta estudiante local");
    assert.ok(periods.rows.length, "Falta periodo local");

    const studentId = students.rows[0].id;
    const periodId = periods.rows[0].id;

    async function scenario(
      decision: "approved" | "rejected",
      deliverySucceeds: boolean,
    ) {
      const created = await client.query(
        `INSERT INTO public.student_profile_photo_submissions
          (student_id, academic_period_id, photo_path,
           status, is_initial_photo, consumes_change)
         VALUES ($1, $2, $3, 'pending', false, false)
         RETURNING id`,
        [
          studentId,
          periodId,
          `tests/13-7E/${crypto.randomUUID()}.jpg`,
        ],
      );

      const submissionId = created.rows[0].id;

      await client.query(
        `UPDATE public.student_profile_photo_submissions
         SET status = $1, reviewed_at = now()
         WHERE id = $2`,
        [decision, submissionId],
      );

      const queued = await client.query(
        `SELECT id, status, decision
         FROM public.profile_photo_review_notifications
         WHERE submission_id = $1`,
        [submissionId],
      );

      assert.equal(queued.rows.length, 1);
      assert.equal(queued.rows[0].status, "pending");
      assert.equal(queued.rows[0].decision, decision);

      const claimed = await client.query(
        `SELECT *
         FROM public.claim_profile_photo_review_notifications(5)`,
      );

      const task = claimed.rows.find(
        (row: { submission_id: string }) => row.submission_id === submissionId,
      );

      assert.ok(task, "La tarea no fue reclamada");
      assert.ok(task.claim_token);

      const sends: string[] = [];

      const result = await processPhotoNotification(task, {
        getTokens: async (uid) => {
          assert.equal(uid, studentId);

          return [{
            id: crypto.randomUUID(),
            user_id: studentId,
            token: "TOKEN_FICTICIO_NO_UTILIZABLE",
            platform: "android",
          }];
        },

        getAccessToken: async () => "ACCESO_FICTICIO",

        send: async (_accessToken, sentTask, token) => {
          assert.equal(sentTask.student_id, studentId);
          assert.equal(sentTask.decision, decision);
          assert.equal(token.user_id, studentId);

          sends.push(sentTask.id);

          // Firebase FCM NO se utiliza.
          return {
            tokenId: token.id,
            success: deliverySucceeds,
            invalid: false,
          };
        },

        deactivateInvalid: async () => {
          throw new Error("No se esperan tokens inválidos");
        },

        complete: async (id, claimToken, success, error) => {
          const completed = await client.query(
            `SELECT public.complete_profile_photo_review_notification(
               $1, $2, $3, $4
             ) AS completed`,
            [id, claimToken, success, error],
          );

          return completed.rows[0].completed === true;
        },
      });

      assert.equal(sends.length, 1);
      assert.equal(result.sent, deliverySucceeds);
      assert.equal(result.failed, !deliverySucceeds);

      const finished = await client.query(
        `SELECT status, attempt_count, claim_token
         FROM public.profile_photo_review_notifications
         WHERE id = $1`,
        [task.id],
      );

      assert.equal(
        finished.rows[0].status,
        deliverySucceeds ? "sent" : "failed",
      );

      assert.equal(finished.rows[0].claim_token, null);
      assert.ok(finished.rows[0].attempt_count >= 1);
    }

    await t.step("aprobación → trabajador → sent", async () => {
      await scenario("approved", true);
    });

    await t.step("rechazo → trabajador → failed", async () => {
      await scenario("rejected", false);
    });
  } finally {
    if (transactionStarted) {
      await client.query("ROLLBACK");
    }

    await client.end();
  }
});
