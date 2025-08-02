import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { createClient } from "@supabase/supabase-js";

admin.initializeApp();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseKey) {
  logger.error("Supabase URL or Key not set in environment variables.");
  throw new Error("Missing Supabase configuration.");
}

const supabaseAdmin = createClient(supabaseUrl, supabaseKey);

export const sendRecurringPaymentReminders = onSchedule({
  schedule: "every day 09:00",
  timeZone: "America/Mexico_City", // ¡CÁMBIALO A TU ZONA HORARIA!
  secrets: ["SUPABASE_URL", "SUPABASE_SERVICE_KEY"],
}, async (_event) => { // <-- CORRECCIÓN: _event para variable no usada
  logger.log("Iniciando la revisión de transacciones recurrentes...");

  try {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const year = tomorrow.getFullYear();
    const month = String(tomorrow.getMonth() + 1).padStart(2, "0");
    const day = String(tomorrow.getDate()).padStart(2, "0");
    const tomorrowString = `${year}-${month}-${day}`;

    const { data: reminders, error } = await supabaseAdmin
      .from("recurring_transactions")
      .select("description, type, next_due_date, profiles(fcm_token)")
      .eq("next_due_date", tomorrowString)
      .not("profiles", "is", null);

    if (error) {
      logger.error("Error al consultar Supabase:", error.message);
      throw new Error("Fallo al obtener datos de Supabase.");
    }

    if (!reminders || reminders.length === 0) {
      logger.log("No hay recordatorios para enviar hoy. Misión cumplida.");
      return;
    }

    logger.log(`Se encontraron ${reminders.length} recordatorios para enviar.`);

    const notificationPromises = reminders.map(async (reminder) => {
      if (!Array.isArray(reminder.profiles) || reminder.profiles.length === 0) {
        // CORRECCIÓN: Línea dividida para no superar el max-len
        const warnMsg = `Perfil no encontrado para: ${reminder.description}`;
        logger.warn(warnMsg);
        return;
      }
      const fcmToken = reminder.profiles[0].fcm_token;
      if (!fcmToken) {
        // CORRECCIÓN: Línea dividida
        const warnMsg = `Token FCM nulo para: ${reminder.description}`;
        logger.warn(warnMsg);
        return;
      }

      const paymentDate = new Date(`${reminder.next_due_date}T00:00:00`);
      const dateString = paymentDate.getDate();
      const monthString = paymentDate.toLocaleString("es-ES", {
        month: "long",
      });
      const formattedDate = `${dateString} de ${monthString}`;
      const title = reminder.type === "Gasto" ?
        "Recordatorio de Próximo Pago" : "Recordatorio de Próximo Ingreso";
      const body = `Tu próximo ${reminder.type.toLowerCase()} es: ` +
                   `${reminder.description}. Fecha: ${formattedDate}.`;

      const message = {
        token: fcmToken,
        notification: { title, body },
        data: { screen: "/recurring_transactions" },
      };

      try {
        await admin.messaging().send(message);
      } catch (e) {
        logger.error(`Error al enviar notificación para ${reminder.description}:`, e);
      }
    });

    await Promise.all(notificationPromises);
    logger.log("Todas las notificaciones han sido procesadas.");
  } catch (e) {
    logger.error("Error fatal en la función de recordatorios:", e);
  }
});