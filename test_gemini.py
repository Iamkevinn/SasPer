import os
import google.generativeai as genai
from dotenv import load_dotenv

# Carga la variable de entorno desde el archivo .env
load_dotenv()

# Configura la API key
# LÍNEA CORRECTA
api_key = os.getenv("GEMINI_API_KEY") 
if not api_key:
    # Este es el error que estás viendo ahora
    raise ValueError("No se encontró la API Key de Gemini. Asegúrate de que tu archivo .env está correcto.")

genai.configure(api_key=api_key)

# Elige el modelo a utilizar (CORREGIDO)
model = genai.GenerativeModel('gemini-2.5-pro') # <--- ¡ASEGÚRATE DE QUE ESTÁ ASÍ!

# ¡Nuestra primera pregunta!
prompt = "Eres un experto en finanzas. Escribe un haiku sobre el ahorro."

print("Enviando pregunta a Gemini...")

# Envía el prompt al modelo
response = model.generate_content(prompt)

# Imprime la respuesta
print("Respuesta de Gemini:")
print(response.text)