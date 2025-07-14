# main.py

import os
import json
import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query,Request
from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions
import google.generativeai as genai
import firebase_admin
from firebase_admin import credentials, messaging
from fastapi.responses import JSONResponse # Opcional, para control avanzado


# --- 1. CONFIGURACIÓN INICIAL Y CLIENTES ---
# Carga las variables de entorno del archivo .env (para desarrollo local)
# Render usará sus propias variables de entorno configuradas en el dashboard.
load_dotenv()

# --- Configuración del cliente de Supabase (con el fix de SSL para desarrollo local) ---
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")
if not supabase_url or not supabase_key:
    raise RuntimeError("Credenciales de Supabase no encontradas en las variables de entorno.")

# Creamos la opción para deshabilitar la verificación SSL.
# Es útil para algunos entornos de desarrollo locales y no daña la producción.
options = ClientOptions(httpx_client=httpx.Client(verify=False))
supabase: Client = create_client(supabase_url, supabase_key, options=options)
print("✅ Cliente de Supabase inicializado.")

try:
    cred = credentials.Certificate("serviceAccountKey.json") # Asumimos que el archivo estará ahí
    firebase_admin.initialize_app(cred)
    print("Firebase Admin SDK inicializado correctamente.")
except Exception as e:
    print(f"Error al inicializar Firebase Admin SDK: {e}")

# --- Configuración del cliente de Google Gemini ---
gemini_api_key = os.getenv("GEMINI_API_KEY")
if not gemini_api_key:
    raise RuntimeError("No se encontró la API Key de Gemini en las variables de entorno.")
genai.configure(api_key=gemini_api_key)
# Usamos el modelo que sabemos que funciona para ti
gemini_model = genai.GenerativeModel('gemini-2.5-pro') 
print(f"✅ Cliente de Gemini inicializado con el modelo: {gemini_model.model_name}")

# --- 2. APLICACIÓN API ---
app = FastAPI(
    title="API de Finanzas Personales con IA",
    description="Conecta Flutter, Supabase y Gemini para análisis financieros."
)

# --- 3. ENDPOINTS ---
@app.get("/", tags=["General"])
def read_root():
    """Endpoint de bienvenida para verificar que el servidor está en funcionamiento."""
    return {"status": "ok", "message": "Servidor de Finanzas Personales con IA en funcionamiento."}

@app.get("/api/analisis-financiero", tags=["Análisis IA"])
async def generar_analisis_financiero(
    user_id: str = Query(..., description="El UUID del usuario de Supabase a analizar.")
):
    print(f"\n--- [NUEVA PETICIÓN] para el usuario: {user_id} ---")
    
    try:
        # --- PASO A: Consultar Supabase ---
        print("1. Consultando transacciones en Supabase...")
        
        # ¡IMPORTANTE! Asegúrate de que este sea el nombre correcto de tu columna de fecha.
        COLUMNA_FECHA = 'created_at' 
        
        response = supabase.table('transactions') \
                           .select(f'description, amount, type, category, {COLUMNA_FECHA}') \
                           .eq('user_id', user_id) \
                           .order(COLUMNA_FECHA, desc=True) \
                           .limit(50) \
                           .execute()
        
        if not response.data:
            print("Resultado: No se encontraron transacciones.")
            return {"analisis": "No he encontrado transacciones para analizar. ¡Empieza a registrar tus gastos para recibir tu primer análisis!"}

        transactions = response.data
        print(f"2. Se encontraron {len(transactions)} transacciones.")

        # --- PASO B: Construir el Prompt ---
        print("3. Construyendo el prompt para Gemini...")
        transactions_json = json.dumps(transactions, indent=2, default=str)
        prompt = f"""
        Eres 'Financiero AI', un asesor financiero experto y amigable.
        Analiza las siguientes transacciones de un usuario y proporciónale un resumen claro, una observación clave y un consejo práctico.
        Mantén un tono motivador y cercano.
        
        Datos de las transacciones:
        ```json
        {transactions_json}
        ```
        """
        print("4. Prompt generado. Enviando a Gemini...")

        # --- PASO C: Llamar a Gemini ---
        safety_settings = {
            'HARM_CATEGORY_HARASSMENT': 'BLOCK_NONE', 'HARM_CATEGORY_HATE_SPEECH': 'BLOCK_NONE',
            'HARM_CATEGORY_SEXUALLY_EXPLICIT': 'BLOCK_NONE', 'HARM_CATEGORY_DANGEROUS_CONTENT': 'BLOCK_NONE',
        }
        gemini_response = gemini_model.generate_content(prompt, safety_settings=safety_settings)
        
        print("5. ¡ÉXITO! Análisis recibido de Gemini.")
        return {"analisis": gemini_response.text}

    except Exception as e:
        print(f"--- ¡ERROR! Ocurrió un error inesperado: {e} ---")
        raise HTTPException(status_code=500, detail=f"No se pudo completar el análisis. Error: {str(e)}")

# --- AÑADE EL NUEVO ENDPOINT DE NOTIFICACIONES ---
@app.post("/check-budget-on-transaction")
async def check_budget_on_transaction(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        category_name = data.get('category')
        
        if not all([user_id, category_name]):
            return JSONResponse(status_code=400, content={"error": "user_id y category_name son requeridos"})
    except Exception:
        return JSONResponse(status_code=400, content={"error": "Cuerpo de la solicitud inválido"})

    try:
        # 1. Encontrar el presupuesto del usuario para esa categoría
        budget_response = supabase.table('budgets').select('amount').eq('user_id', user_id).eq('category', category_name).single().execute()

        if not budget_response.data:
            print(f"No se encontró presupuesto para el usuario {user_id} y categoría {category_name}.")
            return JSONResponse(status_code=200, content={"message": "No hay presupuesto para esta categoría, no se hace nada."})

        budget_amount = float(budget_response.data['amount'])
        
        # 2. Calcular el total gastado en esa categoría este mes
        from datetime import datetime, date
        today = date.today()
        first_day_of_month = today.replace(day=1).isoformat()
        
        # Para el último día, necesitamos manejar el fin de mes correctamente
        import calendar
        _, last_day = calendar.monthrange(today.year, today.month)
        last_day_of_month = today.replace(day=last_day).isoformat()

        transactions_response = supabase.table('transactions').select('amount', count='exact').eq('user_id', user_id).eq('type', 'Gasto').eq('category', category_name).gte('transaction_date', first_day_of_month).lte('transaction_date', last_day_of_month).execute()
        
        total_spent = sum(float(t['amount']) for t in transactions_response.data)

        # 3. Verificar umbrales
        if budget_amount == 0:
            percentage_spent = 0
        else:
            percentage_spent = (total_spent / budget_amount) * 100
        
        print(f"Usuario: {user_id}, Cat: {category_name}, Gastado: {total_spent}/{budget_amount} ({percentage_spent:.2f}%)")

        notification_title = None
        notification_body = None

        # Aquí podríamos añadir lógica para no notificar varias veces (ej. guardar último umbral notificado)
        if 100 <= percentage_spent:
            notification_title = 'Presupuesto Excedido'
            notification_body = f'¡Cuidado! Has superado tu presupuesto para "{category_name}".'
        elif 80 <= percentage_spent < 100:
            notification_title = 'Alerta de Presupuesto'
            notification_body = f'Ya has utilizado el {int(percentage_spent)}% de tu presupuesto para "{category_name}".'

        # 4. Si hay que notificar, buscar token y enviar
        if notification_title:
            token_response = supabase.table('profiles').select('fcm_token').eq('id', user_id).single().execute()
            if token_response.data and token_response.data.get('fcm_token'):
                fcm_token = token_response.data['fcm_token']
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=notification_title,
                        body=notification_body
                    ),
                    token=fcm_token,
                    data={'screen': 'budgets'} # Llevar al usuario a la pantalla de presupuestos
                )
                messaging.send(message)
                print(f"Notificación de presupuesto enviada a {user_id}")
                return JSONResponse(status_code=200, content={"success": True, "message": "Notificación enviada."})
        
        return JSONResponse(status_code=200, content={"success": True, "message": "Umbral no alcanzado, no se envió notificación."})

    except Exception as e:
        print(f"Error procesando el chequeo de presupuesto: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})