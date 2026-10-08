# Plan v1.0 (entregable para revisión)

Objetivo: una versión que se pueda instalar y usar de punta a punta, con cada
regla respaldada por una fuente publicada y todos los datos en el teléfono.

## Tareas

1. **Base de alimentos offline.** Subconjunto del USDA FoodData Central (dominio
   público) con nombres en español, embebido en la app. Búsqueda, porción en
   gramos, kcal y macros.
2. **Código de barras (opcional).** Consulta a Open Food Facts solo cuando la
   persona escanea; se envía únicamente el código de barras.
3. **Metas.** Mantener o bajar peso con déficit respaldado por guía. Proteína de
   referencia con fuente.
4. **Rutina generada.** Plan de cuerpo completo según ACSM (frecuencia, series,
   repeticiones, descanso) y sesión con varios ejercicios y temporizador de
   descanso.
5. **Progreso.** Historial de entrenos, peso corporal y gráficas.
6. **Actividad semanal.** Minutos de actividad contra la recomendación de la
   OMS 2020.
7. **Apple Health y Health Connect.** Leer peso, pasos, pulso en reposo y
   energía activa; escribir entrenos. Siempre opcional.
8. **Pulso por cámara (beta).** Dedo sobre cámara y flash; algoritmo en el
   núcleo con control de calidad de señal.
9. **Privacidad.** Exportar e importar los datos en JSON, borrar todo, política
   de privacidad y términos.
10. **Pulido.** Ícono, nombre, tema, textos, accesibilidad, CHANGELOG,
    CONTRIBUTING.
11. **APK de Android** compilado y verificado.

## Fuera de v1 (con motivo)

- Conteo de repeticiones por cámara (pose): necesita pruebas en dispositivo real
  para medir precisión antes de prometerlo.
- Comida por foto: error de porciones demasiado alto para "solo datos
  verificados".
- Reglas por condición (diabetes, hipertensión, embarazo...): requieren guía
  específica y, idealmente, revisión profesional.
- Ajuste automático de la rutina según la nota del día: ninguna fuente publicada
  define los cortes.
