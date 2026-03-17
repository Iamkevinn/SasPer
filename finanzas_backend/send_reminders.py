import os
import datetime
import requests
from supabase import create_client, Client

def send_recurring_payment_reminders():
    """
    Busca transacciones recurrentes que vencen mañana y envía notificaciones push.
    """
    print("Iniciando la revisión de transacciones recurrentes...")

    try:
        # 1. Cargar las variables de entorno de forma segura desde Render
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_KEY") # Usamos la clave de servicio para tener acceso total
        fcm_server_key = os.getenv("FCM_SERVER_KEY")

        if not all([supabase_url, supabase_key, fcm_server_key]):
            print("Error: Faltan variables de entorno (SUPABASE_URL, SUPABASE_SERVICE_KEY, o FCM_SERVER_KEY).")
            return

        # 2. Conectarse a Supabase
        supabase: Client = create_client(supabase_url, supabase_key)

        # 3. Calcular la fecha de mañana
        tomorrow = datetime.date.today() + datetime.timedelta(days=1)
        tomorrow_str = tomorrow.strftime("%Y-%m-%d")

        # 4. Consultar las transacciones que vencen mañana
        response = supabase.from_("recurring_transactions") \
            .select("description, type, next_due_date, profiles(fcm_token)") \
            .eq("next_due_date", tomorrow_str) \
            .not_("profiles", "is", "null") \
            .execute()

        reminders = response.data
        if not reminders:
            print("No hay recordatorios para enviar hoy. Misión cumplida.")
            return

        print(f"Se encontraron {len(reminders)} recordatorios para enviar.")

        # 5. Iterar y enviar notificaciones
        for reminder in reminders:
            profile = reminder.get("profiles")
            if not profile or not profile.get("fcm_token"):
                print(f"Advertencia: No se encontró token FCM para la transacción: {reminder['description']}")
                continue

            fcm_token = profile["fcm_token"]
            
            payment_date = datetime.datetime.strptime(reminder["next_due_date"], "%Y-%m-%d")
            # Aquí puedes mejorar el formato del mes si es necesario
            formatted_date = f"{payment_date.day} de {payment_date.strftime('%B').lower()}"

            title = "Recordatorio de Próximo Pago" if reminder["type"] == "Gasto" else "Recordatorio de Próximo Ingreso"
            body = f"Tu próximo {reminder['type'].lower()} es: {reminder['description']}. Fecha: {formatted_date}."

            # Construir el payload para FCM
            headers = {
                "Authorization": f"key={fcm_server_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "to": fcm_token,
                "notification": {
                    "title": title,
                    "body": body
                },
                "data": {
                    "screen": "/recurring_transactions"
                }
            }

            # Enviar la petición a FCM
            fcm_response = requests.post("https://fcm.googleapis.com/fcm/send", json=payload, headers=headers)

            if fcm_response.status_code == 200:
                print(f"Notificación enviada con éxito para: {reminder['description']}")
            else:
                print(f"Error al enviar notificación para {reminder['description']}: {fcm_response.text}")

    except Exception as e:
        print(f"Error fatal en la función de recordatorios: {e}")

def send_goal_reminders():
    """
    Busca insights de tipo 'goal_saving_reminder' y envía notificaciones push.
    """
    print("Iniciando revisión de metas...")
    try:
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_KEY")
        fcm_server_key = os.getenv("FCM_SERVER_KEY")
        
        supabase = create_client(supabase_url, supabase_key)

        # 1. Buscar insights de metas pendientes
        response = supabase.from_("insights") \
            .select("id, user_id, metadata, profiles(fcm_token)") \
            .eq("type", "goal_saving_reminder") \
            .eq("is_read", False) \
            .execute()

        insights = response.data
        if not insights:
            print("No hay metas para recordar hoy.")
            return

        for insight in insights:
            profile = insight.get("profiles")
            if not profile or not profile.get("fcm_token"):
                continue

            # 2. Extraer datos del JSON metadata
            meta = insight.get("metadata", {})
            goal_name = meta.get("goal_name", "tu meta")
            savings_amount = meta.get("savings_amount", 0)

            # 3. Enviar notificación Push (Firebase)
            headers = {"Authorization": f"key={fcm_server_key}", "Content-Type": "application/json"}
            payload = {
                "to": profile["fcm_token"],
                "notification": {
                    "title": "✨ Hoy toca ahorrar para tu meta",
                    "body": f"¡Aporta ${savings_amount} para \"{goal_name}\"!"
                },
                "data": {
                    "type": "goal_reminder",
                    "goal_id": meta.get("goal_id")
                }
            }
            
            requests.post("https://fcm.googleapis.com/fcm/send", json=payload, headers=headers)
            print(f"Notificación de ahorro enviada a usuario {insight['user_id']}")

    except Exception as e:
        print(f"Error en send_goal_reminders: {e}")

# Y finalmente, asegúrate de llamar a ambas funciones en el __main__
if __name__ == "__main__":
    send_recurring_payment_reminders()
    send_goal_reminders() # <-- Añade esta línea