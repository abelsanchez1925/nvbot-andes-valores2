# InvBot — Asistente Conversacional para Soporte al Inversionista

Proyecto académico de diseño e implementación de un chatbot conversacional conectado a una base de datos relacional en tiempo real, desarrollado para la maestría en Inteligencia de Negocios y Ciencia de Datos, materia **Inteligencia Artificial**.

- **Estudiante:** Abel Sánchez
- **Profesor:** Juan Simón Isidro
- **Sector:** Mercado Bursátil (Bolsa de Valores de Quito / Guayaquil)
- **Caso de uso:** Soporte al Inversionista Activo — chatbot **InvBot** para la correduría ficticia **Andes Valores S.A.**

## ¿Qué hace InvBot?

InvBot identifica al cliente (número de cuenta + cédula), responde consultas sobre saldos, estado de órdenes, tarifas, horarios de mercado y dividendos, y permite reportar incidencias generando un ticket de soporte. Todo el flujo está conectado a una base de datos **PostgreSQL real (Supabase)**, no a datos simulados en memoria:

- La autenticación consulta las tablas `clientes`, `cuentas` y `ordenes` en vivo.
- Cada ticket reportado se inserta en la tabla `tickets` real, con una llave de idempotencia para evitar duplicados ante reintentos.
- El panel lateral del prototipo se actualiza al instante mediante **Supabase Realtime** (canal `postgres_changes`) cuando se crea un nuevo ticket, sin necesidad de refrescar la página.

## Estructura del repositorio

```
invbot-repo/
├── README.md                      # Este archivo
├── database/
│   └── supabase_setup.sql         # Esquema completo, datos de prueba, RLS y Realtime
├── prototype/
│   └── invbot_prototipo.html      # Prototipo funcional (HTML/CSS/JS + Supabase JS)
├── docs/
│   ├── informe_tecnico.pdf        # Informe técnico completo (entregable oficial)
│   └── informe_tecnico.html       # Versión HTML del informe (mismo contenido)
├── slides/
│   └── diapositivas_invbot.pptx   # Diapositivas de apoyo para la sustentación
└── video/
    └── guion_video.md             # Guion segundo a segundo para el video de sustentación
```

## Cómo levantar el entorno desde cero

1. **Crear el proyecto en Supabase**
   Crea un proyecto nuevo en [supabase.com](https://supabase.com) (plan gratuito es suficiente).

2. **Ejecutar el esquema**
   Abre el **SQL Editor** de tu proyecto Supabase, pega el contenido de `database/supabase_setup.sql` y ejecútalo. Esto crea las 6 tablas (`clientes`, `cuentas`, `catalogo_instrumentos`, `ordenes`, `tickets`, `interacciones_chatbot`), inserta los datos de prueba, activa Row Level Security con políticas permisivas para el prototipo, y habilita Realtime en la tabla `tickets`.

3. **Obtener las credenciales del proyecto**
   En **Project Settings → API Keys**, copia:
   - la **Project URL** (algo como `https://xxxx.supabase.co`)
   - la **llave publicable** (`sb_publishable_...`), segura para usarse en el navegador porque RLS está activo.

4. **Conectar el prototipo**
   Abre `prototype/invbot_prototipo.html` y reemplaza las constantes `SUPABASE_URL` y `SUPABASE_KEY` (líneas ~259-260) con tus propios valores.

5. **Ejecutar el prototipo**
   Al ser un único archivo HTML autocontenido, basta con abrirlo en un navegador (doble clic, o servirlo con cualquier servidor estático). No requiere backend propio ni build step.

### Cuentas de prueba

| Cuenta | Cédula | Cliente |
|---|---|---|
| `AV-00234` | `1712345678` | María Fernanda López |
| `AV-00591` | `0923456781` | Carlos Ramírez |

## Notas de seguridad

- La llave usada en el prototipo es la **llave publicable** de Supabase, diseñada explícitamente para exponerse en código de cliente cuando Row Level Security está activo (como es el caso aquí). La contraseña de la base de datos nunca se usa ni se almacena en este repositorio.
- Las políticas RLS de este proyecto son permisivas a propósito (`USING (true)`), documentado así en la sección 7 del informe técnico, porque el objetivo es una demo académica accesible desde el navegador sin capa de autenticación de usuarios final. En un entorno de producción real, estas políticas se restringirían por sesión autenticada.

## Entregables del proyecto

Este repositorio cubre el entregable **"Repositorio / configuración técnica"** de la actividad. Los otros tres entregables son:

1. **Informe técnico** — `docs/informe_tecnico.pdf`
2. **Prototipo funcional** — enlace del artifact publicado (ver informe técnico, sección 8)
3. **Repositorio / configuración técnica** — este repositorio
4. **Video de sustentación** — grabado siguiendo `video/guion_video.md`, apoyado en `slides/diapositivas_invbot.pptx`
