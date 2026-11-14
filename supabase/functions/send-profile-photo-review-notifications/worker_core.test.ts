import {
  type PhotoTask,
  processPhotoNotification,
  type WorkerDependencies,
} from "./worker_core.ts";

const task: PhotoTask = {
  id: "11111111-1111-4111-8111-111111111111",
  submission_id: "22222222-2222-4222-8222-222222222222",
  student_id: "33333333-3333-4333-8333-333333333333",
  decision: "approved",
  claim_token: "44444444-4444-4444-8444-444444444444",
};

const device = {
  id: "55555555-5555-4555-8555-555555555555",
  user_id: task.student_id,
  token: "token-ficticio",
  platform: "android",
};

function check(value: boolean, message: string): void {
  if (!value) throw new Error(message);
}

function dependencies(
  overrides: Partial<WorkerDependencies> = {},
): WorkerDependencies {
  return {
    getTokens: async () => [device],
    getAccessToken: async () => "oauth-ficticio",
    send: async (_access, _task, token) => ({
      tokenId: token.id,
      success: true,
      invalid: false,
    }),
    deactivateInvalid: async () => {},
    complete: async () => true,
    ...overrides,
  };
}

Deno.test("13.5F - aprobación: recorrido completo", async () => {
  let completed = false;

  const result = await processPhotoNotification(
    task,
    dependencies({
      getTokens: async (id) => {
        check(id === task.student_id, "Destinatario incorrecto");
        return [device];
      },
      complete: async (id, claim, success, error) => {
        check(id === task.id, "Tarea incorrecta");
        check(claim === task.claim_token, "Claim incorrecto");
        check(success && error === null, "Resultado incorrecto");
        completed = true;
        return true;
      },
    }),
  );

  check(completed, "No se registró el resultado");
  check(result.sent && !result.failed, "No se marcó como enviado");
});

Deno.test("13.5F - rechazo: conserva la decisión", async () => {
  const rejected = { ...task, decision: "rejected" as const };

  const result = await processPhotoNotification(
    rejected,
    dependencies({
      send: async (_access, current, token) => {
        check(current.decision === "rejected", "Decisión alterada");
        return {
          tokenId: token.id,
          success: true,
          invalid: false,
        };
      },
    }),
  );

  check(result.sent, "No se procesó el rechazo");
});

Deno.test("13.5F - varios dispositivos y token inválido", async () => {
  const second = {
    ...device,
    id: "66666666-6666-4666-8666-666666666666",
    token: "segundo-token-ficticio",
  };

  let deactivated: string[] = [];

  const result = await processPhotoNotification(
    task,
    dependencies({
      getTokens: async () => [device, second],
      send: async (_access, _task, token) => ({
        tokenId: token.id,
        success: token.id === device.id,
        invalid: token.id === second.id,
      }),
      deactivateInvalid: async (_id, ids) => {
        deactivated = ids;
      },
    }),
  );

  check(result.sent, "Entrega parcial no reconocida");
  check(result.invalidTokens === 1, "Conteo inválido");
  check(
    deactivated.length === 1 && deactivated[0] === second.id,
    "Desactivación incorrecta",
  );
});

Deno.test("13.5F - fallo temporal: programa resultado fallido", async () => {
  let failureRecorded = false;

  const result = await processPhotoNotification(
    task,
    dependencies({
      send: async (_access, _task, token) => ({
        tokenId: token.id,
        success: false,
        invalid: false,
      }),
      complete: async (_id, _claim, success, error) => {
        check(!success && !!error, "Fallo no registrado");
        failureRecorded = true;
        return true;
      },
    }),
  );

  check(result.failed && !result.sent, "Fallo tratado como éxito");
  check(failureRecorded, "Faltó registrar el fallo");
});

Deno.test("13.5F - sin tokens: no llama a Firebase", async () => {
  let firebaseCalled = false;

  const result = await processPhotoNotification(
    task,
    dependencies({
      getTokens: async () => [],
      getAccessToken: async () => {
        firebaseCalled = true;
        return "oauth-ficticio";
      },
    }),
  );

  check(result.noTokens && result.failed, "Estado incorrecto");
  check(!firebaseCalled, "Se contactó Firebase sin tokens");
});

Deno.test("13.5F - reclamación vencida o inválida", async () => {
  const result = await processPhotoNotification(
    task,
    dependencies({
      complete: async () => false,
    }),
  );

  check(!result.sent && result.failed, "Claim inválido aceptado");
});

Deno.test("13.5F - error de conexión a Supabase", async () => {
  let failureRecorded = false;

  const result = await processPhotoNotification(
    task,
    dependencies({
      getTokens: async () => {
        throw new Error("Fallo ficticio de Supabase");
      },
      complete: async (_id, _claim, success) => {
        failureRecorded = !success;
        return true;
      },
    }),
  );

  check(result.failed, "Error tratado como éxito");
  check(failureRecorded, "No se registró el error");
});
