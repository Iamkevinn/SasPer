# main.py

import os
import json
import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions
import google.generativeai as genai

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