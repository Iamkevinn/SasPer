# test_supabase_conexion.py (VERSIÓN FINAL Y CORREGIDA)

import os
import httpx
from dotenv import load_dotenv
from supabase import create_client, Client
# --- NUEVO: Importamos la clase de opciones correcta ---
from supabase.lib.client_options import ClientOptions

print("--- INICIANDO PRUEBA DE CONEXIÓN A SUPABASE (VERSIÓN CORREGIDA) ---")

try:
    # 1. Cargar credenciales
    load_dotenv()
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_KEY")
    if not url or not key:
        raise ValueError("No se encontraron las credenciales de Supabase en .env")
    
    print("Credenciales de Supabase cargadas.")

    # 2. Crear el cliente con las opciones en el formato CORRECTO
    #    Creamos un objeto ClientOptions y le pasamos nuestro cliente httpx modificado.
    #    Esta es la forma correcta que la librería espera.
    options = ClientOptions(
        httpx_client=httpx.Client(verify=False)
    )
    
    supabase: Client = create_client(
        url,
        key,
        options=options
    )
    print("Cliente de Supabase creado correctamente con SSL desactivado.")

    # 3. Hacer la consulta más simple posible
    print("Intentando obtener UN registro de la tabla 'profiles'...")
    
    response = supabase.table('profiles').select('*').limit(1).execute()

    # 4. Imprimir resultado
    print("\n--- ¡ÉXITO! LA CONEXIÓN A SUPABASE FUNCIONA ---")
    print("Datos recibidos:")
    print(response.data)
    print("---------------------------------------------")

except Exception as e:
    print("\n--- ¡ERROR! LA CONEXIÓN A SUPABASE FALLÓ ---")
    print(f"El error detallado es: {e}")
    print("---------------------------------------------")