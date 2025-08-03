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

if __name__ == "__main__":
    send_recurring_payment_reminders()