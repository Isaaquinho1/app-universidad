import {
  notificationContent,
  sendToDevice,
} from "./index.ts";

function verify(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

const task = {
  id: "11111111-1111-4111-8111-111111111111",
  submission_id: "22222222-2222-4222-8222-222222222222",
  student_id: "33333333-3333-4333-8333-333333333333",
  decision: "approved" as "approved" | "rejected",
  claim_token: "44444444-4444-4444-8444-444444444444",
};

const token = {
  id: "55555555-5555-4555-8555-555555555555",
  user_id: task.student_id,
  token: "token-ficticio-no-valido",
  platform: "android",
};

Deno.test("13.5D.2 - aprobación: mensaje y destinatario", async () => {
  let calls = 0;

  const fakeFetch: typeof fetch = async (_url, options) => {
    calls++;

    const payload = JSON.parse(String(options?.body));
    const message = payload.message;

    verify(message.token === token.token, "Destinatario incorrecto");
    verify(
      message.notification.title === "Fotografía aprobada",
      "Título incorrecto",
    );
    verify(
      message.data.user_id === task.student_id,
      "Identificador de estudiante incorrecto",
    );
    verify(
      message.data.submission_id === task.submission_id,
      "Identificador de solicitud incorrecto",
    );
    verify(
      message.data.type === "profile_photo_review",
      "Tipo de notificación incorrecto",
    );

    return Response.json({ name: "mensaje-ficticio" }, { status: 200 });
  };

  const result = await sendToDevice(
    "oauth-ficticio",
    task,
    token,
    fakeFetch,
  );

  verify(result.success === true, "Envío simulado no exitoso");
  verify(result.invalid === false, "Token marcado inválido");
  verify(calls === 1, "Número incorrecto de solicitudes");
});

Deno.test("13.5D.2 - rechazo: privacidad y mensaje", async () => {
  const rejectedTask = {
    ...task,
    decision: "rejected" as const,
  };

  const privateReason = "Motivo privado que no debe viajar por FCM";

  const fakeFetch: typeof fetch = async (_url, options) => {
    const body = String(options?.body);
    const payload = JSON.parse(body);

    verify(
      payload.message.notification.title === "Fotografía rechazada",
      "Título de rechazo incorrecto",
    );

    verify(
      !body.includes(privateReason),
      "El motivo privado se incluyó en FCM",
    );

    verify(
      payload.message.data.decision === "rejected",
      "Decisión incorrecta",
    );

    return Response.json({ name: "mensaje-ficticio" }, { status: 200 });
  };

  const content = notificationContent("rejected");

  verify(
    !JSON.stringify(content).includes(privateReason),
    "Motivo privado en el contenido",
  );

  const result = await sendToDevice(
    "oauth-ficticio",
    rejectedTask,
    token,
    fakeFetch,
  );

  verify(result.success === true, "Rechazo simulado falló");
});

Deno.test("13.5D.2 - token FCM inválido", async () => {
  const fakeFetch: typeof fetch = async () =>
    Response.json(
      {
        error: {
          details: [{ errorCode: "UNREGISTERED" }],
        },
      },
      { status: 404 },
    );

  const result = await sendToDevice(
    "oauth-ficticio",
    task,
    token,
    fakeFetch,
  );

  verify(result.success === false, "Se aceptó un token inválido");
  verify(result.invalid === true, "No se detectó token inválido");
});

Deno.test("13.5D.2 - error temporal de Firebase", async () => {
  const fakeFetch: typeof fetch = async () =>
    Response.json(
      { error: { status: "UNAVAILABLE" } },
      { status: 503 },
    );

  const result = await sendToDevice(
    "oauth-ficticio",
    task,
    token,
    fakeFetch,
  );

  verify(result.success === false, "Error 503 considerado éxito");
  verify(result.invalid === false, "Error temporal invalidó token");
});

Deno.test("13.5D.2 - interrupción de conexión", async () => {
  const fakeFetch: typeof fetch = async () => {
    throw new Error("Fallo de conexión simulado");
  };

  const result = await sendToDevice(
    "oauth-ficticio",
    task,
    token,
    fakeFetch,
  );

  verify(result.success === false, "Fallo de red considerado éxito");
  verify(result.invalid === false, "Fallo de red invalidó token");
});
