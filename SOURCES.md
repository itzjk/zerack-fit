# Fuentes

Regla del proyecto: **ninguna fórmula, constante o regla entra al código sin una
fuente publicada**. Cada una vive en `packages/zerack_core/lib/src/source.dart`
con su identificador estable.

| Módulo | Qué usamos | Fuente |
|---|---|---|
| Energía en reposo | Ecuación de Mifflin-St Jeor | Mifflin et al., *Am J Clin Nutr* 1990;51(2):241-247 |
| Gasto total | PAL por estilo de vida (1.53 / 1.76 / 2.25) | FAO/WHO/UNU, *Human energy requirements*, 2004 |
| Gasto por actividad | kcal = MET × kg × h, valores MET por código | 2024 Adult Compendium of Physical Activities (pacompendium.com) |
| Screening previo | Algoritmo de autorización médica | Riebe et al., *Med Sci Sports Exerc* 2015;47(11):2473-2479 |
| Signos de alarma | Lista de signos y síntomas | Riebe et al. 2015, tabla 1 |
| Progresión de cargas | Regla 2-de-más en 2 sesiones, +2–10 % | ACSM Position Stand, *Med Sci Sports Exerc* 2009;41(3):687-708 |
| Pulso máximo | 208 − 0.7 × edad | Tanaka et al., *J Am Coll Cardiol* 2001;37(1):153-156 |
| Bandas de intensidad | % de frecuencia cardiaca de reserva | ACSM's Guidelines for Exercise Testing and Prescription, 11.ª ed. |
| Readiness diario | Índice de Hooper (4 ítems, 1–7) | Hooper & Mackinnon, *Sports Med* 1995;20(5):321-327 |

## Lo que todavía NO tiene fuente (y por eso no está)

- Bajar cargas automáticamente: ACSM 2009 no define una regla, así que no se hace.
- Umbrales del readiness 0–100: es una escala lineal del índice de Hooper para
  mostrarlo, **no un corte validado**. Se compara a la persona contra sí misma.
- Reglas por condición (diabetes, hipertensión, embarazo...): entran solo con
  guía citada y, cuando sea posible, revisión profesional.
