-- WOOP (Wish, Outcome, Obstacle, Plan): Wish sigue en title + description.
ALTER TABLE public.manifestations
  ADD COLUMN IF NOT EXISTS outcome TEXT,
  ADD COLUMN IF NOT EXISTS obstacle TEXT,
  ADD COLUMN IF NOT EXISTS plan TEXT;

COMMENT ON COLUMN public.manifestations.outcome IS 'WOOP: mejor resultado y sensación al cumplir el deseo';
COMMENT ON COLUMN public.manifestations.obstacle IS 'WOOP: obstáculo interno principal';
COMMENT ON COLUMN public.manifestations.plan IS 'WOOP: regla si-entonces (plan de acción ante el obstáculo)';
