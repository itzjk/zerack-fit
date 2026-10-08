# Fuentes

Regla del proyecto: **ninguna fórmula, constante o regla entra al código sin una
fuente publicada**. Cada una vive en `packages/zerack_core/lib/src/source.dart`
con su identificador estable y se muestra en la app (Perfil → Fuentes).

| Módulo | Qué usamos | Fuente |
|---|---|---|
| Energía en reposo | Ecuación de Mifflin-St Jeor | Mifflin et al., *Am J Clin Nutr* 1990;51(2):241-247 |
| Margen de error | ±10 % en reposo | Frankenfield et al., *J Am Diet Assoc* 2005;105(5):775-789 |
| Gasto total | PAL por estilo de vida (1.53 / 1.76 / 2.25) | FAO/WHO/UNU, *Human energy requirements*, 2004 |
| Gasto por actividad | kcal = MET × kg × h, valores MET por código | 2024 Adult Compendium of Physical Activities (pacompendium.com) |
| Bajar de peso | Déficit de 500 kcal/día (extremo bajo de 500–1000) | ACSM Position Stand, *Med Sci Sports Exerc* 2001;33(12):2145-2156 |
| Proteína | 1.4–2.0 g/kg/día para quien hace ejercicio | ISSN Position Stand, *J Int Soc Sports Nutr* 2017;14:20 |
| Alimentos | Nutrientes por 100 g y porciones | USDA FoodData Central, SR Legacy (abril 2018), dominio público |
| Productos empacados | Nutrientes por código de barras | Open Food Facts (ODbL), datos de la comunidad, marcados como tales |
| Screening previo | Algoritmo de autorización médica | Riebe et al., *Med Sci Sports Exerc* 2015;47(11):2473-2479 |
| Signos de alarma | Lista de signos y síntomas | Riebe et al. 2015, tabla 1 |
| Progresión de cargas | Regla 2-de-más en 2 sesiones, +2–10 % | ACSM Position Stand, *Med Sci Sports Exerc* 2009;41(3):687-708 |
| Plan de fuerza | 2–3 días, 8–12 reps, series y descansos | ACSM 2009 y Garber et al., *Med Sci Sports Exerc* 2011;43(7):1334-1359 |
| Actividad semanal | 150–300 min moderados, vigorosos ×2, fuerza 2+ días | Bull et al. (OMS 2020), *Br J Sports Med* 2020;54(24):1451-1462 |
| Pulso máximo | 208 − 0.7 × edad | Tanaka et al., *J Am Coll Cardiol* 2001;37(1):153-156 |
| Bandas de intensidad | % de frecuencia cardiaca de reserva | ACSM's Guidelines for Exercise Testing and Prescription, 11.ª ed. |
| Readiness diario | Índice de Hooper (4 ítems, 1–7) | Hooper & Mackinnon, *Sports Med* 1995;20(5):321-327 |

## Decisiones conservadoras del proyecto (no son reglas de una guía)

- **La meta de energía nunca baja del gasto en reposo estimado.** La guía de
  ACSM no fija un piso; lo ponemos nosotros por seguridad.
- **Descansos del plan:** usamos el extremo bajo de cada rango de ACSM 2009
  (2 min en multiarticulares, 60 s en monoarticulares).
- **Nivel inicial:** quien ya entrena con regularidad (respuesta del screening)
  empieza en "intermedio" (3 series); quien no, en "principiante" (2 series).

## Lo que todavía NO tiene fuente (y por eso no está)

- Bajar cargas automáticamente: ACSM 2009 no define una regla.
- Umbrales del readiness 0–100: es una escala lineal del índice de Hooper para
  mostrarlo, **no un corte validado**, y no cambia la rutina.
- Reglas por condición (diabetes, hipertensión, embarazo...): entran solo con
  guía citada y, cuando sea posible, revisión profesional.

## Qué hace la IA y qué no

- **Escáner de platos:** la IA solo identifica alimentos y estima gramos. Las
  calorías y macros salen de la base del USDA. La persona confirma.
- **Asistente:** responde con los datos que devuelven sus herramientas (perfil,
  meta, comidas, plan, base del USDA). No diagnostica ni interpreta síntomas.
- **Pulso por cámara:** algoritmo propio (picos + autocorrelación) que rechaza
  la lectura si la señal no es periódica. Es una estimación de bienestar.
