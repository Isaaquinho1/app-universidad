-- Conecta ITT | Catálogo de cuatro carreras del TecNM Tlalpan
-- Cambio incremental. No elimina ni modifica carreras existentes.
-- Los IDs internos son las claves oficiales normalizadas a minúsculas.

BEGIN;

INSERT INTO public.careers (id, name, short_name, active)
VALUES
  (
    'itic-2010-225',
    'Ingeniería en Tecnologías de la Información y Comunicaciones',
    'ITIC-2010-225',
    true
  ),
  (
    'igem-2009-201',
    'Ingeniería en Gestión Empresarial',
    'IGEM-2009-201',
    true
  ),
  (
    'ielc-2010-211',
    'Ingeniería Electrónica',
    'IELC-2010-211',
    true
  ),
  (
    'ladm-2010-234',
    'Licenciatura en Administración',
    'LADM-2010-234',
    true
  )
ON CONFLICT (id) DO NOTHING;

COMMIT;
