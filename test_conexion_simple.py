# test_conexion_simple.py

import os
import google.generativeai as genai
from dotenv import load_dotenv

print("--- INICIANDO PRUEBA DE CONEXIÓN SIMPLE ---")

try:
    # 1. Cargar la API Key
    load_dotenv()
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("No se encontró la API Key en .env")
    
    print("API Key cargada con éxito.")

    # 2. Configurar Gemini
    genai.configure(api_key=api_key)
    
    # Usamos el modelo estable que sabemos que existe
    model = genai.GenerativeModel('gemini-2.5-pro')
    print(f"Modelo '{model.model_name}' seleccionado.")

    # 3. Hacer la pregunta más simple posible
    prompt_simple = "¿Por qué el cielo es azul? Responde brevemente."
    print(f"Enviando prompt: \"{prompt_simple}\"")

    # 4. Generar contenido
    response = model.generate_content(prompt_simple)
    
    # 5. Imprimir resultado
    print("\n--- ¡ÉXITO! LA CONEXIÓN FUNCIONA ---")
    print("Respuesta de Gemini:")
    print(response.text)
    print("------------------------------------")

except Exception as e:
    print("\n--- ¡ERROR! LA CONEXIÓN FALLÓ ---")
    print(f"El error detallado es: {e}")
    print("------------------------------------")