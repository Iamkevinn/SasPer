-- Habilita la extensión pg_cron si aún no está activa
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Elimina el job si ya existe, evita errores en re-aplicaciones
SELECT cron.unschedule('daily-insight-generation');

-- Crea un nuevo cron job que se ejecuta todos los días a las 5:00 AM UTC
SELECT cron.schedule(
  'daily-insight-generation',
  '0 5 * * *',
  $$
    SELECT net.http_post(
      'https://flyqlrujavwndmdqaldr.supabase.co/functions/v1/generate-user-insights',
      '{}'::jsonb,
      '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZseXFscnVqYXZ3bmRtZHFhbGRyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTY0NDI5MSwiZXhwIjoyMDY3MjIwMjkxfQ.0a7kpJaz9cu27u9MMeQxXYlugdeFi0nochX-d4T4gng"}'::jsonb
    )
  $$
);
