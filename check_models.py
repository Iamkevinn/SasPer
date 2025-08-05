# check_models.py
import os
import google.generativeai as genai
from dotenv import load_dotenv

print("Cargando credenciales...")
load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")

if not api_key:
    print("❌ ERROR: No se encontró la clave 'GEMINI_API_KEY' en el archivo .env")
    exit(1)

try:
    genai.configure(api_key=api_key)
    print("✅ ¡Conectado! Modelos compatibles con 'generateContent':\n")

    model_found = False
    for model in genai.list_models():
        if 'generateContent' in model.supported_generation_methods:
            print(f"  - {model.name}")
            model_found = True

    if not model_found:
        print("⚠️ No se encontraron modelos compatibles.")

except Exception as e:
    print(f"❌ Error al conectar o listar modelos: {e}")
