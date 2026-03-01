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
        gemini_response = gemini_model.generate_content(prompt)
        
        print("5. ¡ÉXITO! Análisis recibido de Gemini.")
        return {"analisis": gemini_response.text}

    except Exception as e:
        print(f"--- ¡ERROR! Ocurrió un error inesperado: {e} ---")
        raise HTTPException(status_code=500, detail=f"No se pudo completar el análisis. Error: {str(e)}")

# --- AÑADE EL NUEVO ENDPOINT DE NOTIFICACIONES ---
# Pega este código en tu app.py, reemplazando la función anterior.

@app.post("/check-budget-on-transaction")
async def check_budget_on_transaction(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        category_name = data.get('category')
        
        if not all([user_id, category_name]):
            return JSONResponse(status_code=400, content={"error": "user_id y category son requeridos"})
    except Exception:
        return JSONResponse(status_code=400, content={"error": "Cuerpo de la solicitud inválido"})

    print(f"--- INICIANDO BÚSQUEDA DE PRESUPUESTO PARA CATEGORÍA '{category_name}' ---")

    try:
        # --- PASO 1: OBTENER TODOS LOS PRESUPUESTOS DEL USUARIO ---
        # Este enfoque de depuración nos ayuda a ver qué está devolviendo la base de datos realmente.
        all_budgets_response = supabase.table('budgets').select('*').eq('user_id', user_id).execute()

        if not all_budgets_response.data:
            print(f"RESULTADO: No se encontró NINGÚN presupuesto para el usuario {user_id}.")
            return JSONResponse(status_code=200, content={"message": "El usuario no tiene presupuestos."})

        print(f"DIAGNÓSTICO: Presupuestos encontrados para el usuario: {all_budgets_response.data}")

        # --- PASO 2: ENCONTRAR EL PRESUPUESTO CORRECTO EN PYTHON ---
        # Filtramos la lista en Python. Es menos eficiente pero a prueba de errores de consulta.
        target_budget_data = None
        for budget in all_budgets_response.data:
            if budget.get('category') == category_name:
                target_budget_data = budget
                break # Encontramos el presupuesto, salimos del bucle

        if not target_budget_data:
            print(f"RESULTADO: No se encontró un presupuesto que coincida con la categoría '{category_name}' en la lista de presupuestos del usuario.")
            return JSONResponse(status_code=200, content={"message": "No hay presupuesto para esta categoría específica."})

        budget_amount = float(target_budget_data['amount'])
        print(f"RESULTADO: Presupuesto encontrado en Python para '{category_name}'. Límite: {budget_amount}")
        
        # --- PASO 3: LÓGICA DE CÁLCULO Y NOTIFICACIÓN ---
        from datetime import date
        import calendar

        today = date.today()
        
        # Obtenemos mes y año del presupuesto encontrado
        # Asumimos que la columna 'month' y 'year' existen y son números
        budget_month = int(target_budget_data['month'])
        budget_year = int(target_budget_data['year'])

        # Solo procedemos si la transacción actual está dentro del mes/año del presupuesto
        if not (today.month == budget_month and today.year == budget_year):
             print(f"ADVERTENCIA: La transacción (Mes/Año: {today.month}/{today.year}) no corresponde al período del presupuesto (Mes/Año: {budget_month}/{budget_year}).")
             return JSONResponse(status_code=200, content={"message": "La transacción no aplica al período del presupuesto."})

        # Si estamos en el período correcto, calculamos el gasto
        first_day_of_month = date(budget_year, budget_month, 1).isoformat()
        _, last_day = calendar.monthrange(budget_year, budget_month)
        last_day_of_month = date(budget_year, budget_month, last_day).isoformat()

        print(f"Buscando transacciones entre {first_day_of_month} y {last_day_of_month}")
        transactions_response = supabase.table('transactions').select('amount').eq('user_id', user_id).eq('type', 'Gasto').eq('category', category_name).gte('transaction_date', first_day_of_month).lte('transaction_date', last_day_of_month).execute()
        
        total_spent = sum(float(t['amount']) for t in transactions_response.data)

        # Verificar umbrales
        if budget_amount == 0:
            percentage_spent = 0
        else:
            percentage_spent = (total_spent / budget_amount) * 100
        
        print(f"CÁLCULO FINAL: Usuario: {user_id}, Cat: {category_name}, Gastado: {total_spent}/{budget_amount} ({percentage_spent:.2f}%)")

        notification_title = None
        notification_body = None

        if 100 <= percentage_spent:
            notification_title = 'Presupuesto Excedido'
            notification_body = f'¡Cuidado! Has superado tu presupuesto para "{category_name}".'
        elif 80 <= percentage_spent < 100:
            notification_title = 'Alerta de Presupuesto'
            notification_body = f'Ya has utilizado el {int(percentage_spent)}% de tu presupuesto para "{category_name}".'

        # Si hay que notificar, buscar token y enviar
        if notification_title:
            print(f"DECISIÓN: Se debe enviar notificación. Buscando token FCM para {user_id}...")
            token_response = supabase.table('profiles').select('fcm_token').eq('id', user_id).execute()
            if token_response.data and token_response.data[0].get('fcm_token'):
                fcm_token = token_response.data[0]['fcm_token']
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=notification_title,
                        body=notification_body
                    ),
                    token=fcm_token,
                    data={'screen': 'budgets'}
                )
                messaging.send(message)
                print(f"ÉXITO: Notificación de presupuesto enviada a {user_id}")
                return JSONResponse(status_code=200, content={"success": True, "message": "Notificación enviada."})
            else:
                print(f"ADVERTENCIA: No se pudo encontrar el token FCM para el usuario {user_id}. No se envió notificación.")
        
        print("DECISIÓN: Umbral no alcanzado, no se envió notificación.")
        return JSONResponse(status_code=200, content={"success": True, "message": "Umbral no alcanzado."})

    except Exception as e:
        import traceback
        print(f"ERROR INESPERADO: Error procesando el chequeo de presupuesto:")
        traceback.print_exc() # Imprime el traceback completo para una mejor depuración
        return JSONResponse(status_code=500, content={"error": "Ocurrió un error interno en el servidor."})