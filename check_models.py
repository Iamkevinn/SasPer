# check_models.py
import os
import google.generativeai as genai
from dotenv import load_dotenv

print("Cargando credenciales...")
load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("ERROR: No se pudo encontrar la API Key en el archivo .env")
else:
    try:
        genai.configure(api_key=api_key)
        print("\n¡Conectado! Buscando modelos disponibles para 'generateContent'...\n")
        
        model_found = False
        for m in genai.list_models():
          if 'generateContent' in m.supported_generation_methods:
            print(f"  - {m.name}")
            model_found = True
        
        if not model_found:
            print("No se encontraron modelos compatibles.")

    except Exception as e:
        print(f"Ocurrió un error al conectar o listar modelos: {e}")