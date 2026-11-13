# Store listing — MZD Owner 1.0.0

| | |
|---|---|
| App name | **MZD Owner** |
| Bundle ID / package | `com.jeronimotech.mzdOwner` (iOS) · `com.jeronimotech.mzd_owner` (Android) |
| Seller | Jeronimo SAS (Apple team `6DTDJCKC8X`) |
| Category | App Store: **Navigation** (secondary: Utilities) · Play: **Auto & Vehicles** |
| Age rating | 4+ / Everyone |
| Price | Free, no in-app purchases, no ads |
| Privacy policy URL | https://jeronimotech.github.io/mzd-owner/privacy.html |
| Support URL | https://jeronimotech.github.io/mzd-owner/ |
| Primary language | Spanish (Latin America) · also English |
| Screenshots (iPhone 6.9") | `docs/store/ios/01.png`, `02.png`, `03.png` (1320×2868) |

> Trademark note: don't use "Mazda" in the app name, subtitle, keywords or icon. In the description
> it may appear only as compatibility ("works with Mazda and other OBD-II cars").

## Spanish (es-419)

**Subtítulo (30):** Tu carro en vivo y al día

**Texto promocional (170):** Datos en vivo de tu carro, recordatorios de mantenimiento, códigos de falla explicados con IA y un asistente por voz. Funciona con un adaptador OBD-II Bluetooth LE.

**Descripción:**

MZD Owner convierte tu celular en el tablero inteligente de tu carro.

Conecta un adaptador OBD-II Bluetooth LE al puerto bajo el timón y mira en tiempo real:
• Velocidad, RPM y carga del motor
• Temperatura del motor, de admisión y exterior
• Voltaje de la batería y nivel de gasolina (según el modelo)

Mantenimiento sin olvidos
• Aceite, llantas, filtros, frenos, bujías y refrigerante, por kilómetros o por meses, lo que llegue primero
• SOAT y revisión técnico-mecánica
• Intervalos editables y alertas de lo vencido o próximo

Diagnóstico del check engine
• Lee los códigos de falla al conectar
• "Explicar con IA": qué significa el código, qué tan urgente es y qué revisar en el taller

Asistente por voz
• Pregunta por pico y placa, gasolineras cercanas, el clima o las noticias, y escucha la respuesta

En la pantalla de bloqueo, la Dynamic Island y el tablero de CarPlay
• Widget "Estado de mi carro" y actividad en vivo "En ruta" con velocidad, temperatura y batería

Prueba la app sin adaptador con el modo demo.

Compatible con la mayoría de carros a gasolina con puerto OBD-II (incluidos modelos Mazda 2014–2020).
Código abierto: github.com/jeronimotech/mzd-owner. MZD Owner es un proyecto independiente, no afiliado con Mazda Motor Corporation.

**Palabras clave (100):** obd2,obd,elm327,tablero,mantenimiento,check engine,diagnostico,carro,auto,carplay,bluetooth,aceite,soat

## English (en-US)

**Subtitle:** Your car, live and on schedule

**Description:** MZD Owner turns your phone into a smart dashboard for your car. Plug a Bluetooth LE OBD-II adapter
into the port under the steering wheel to see speed, RPM, engine and outside temperature, battery voltage and fuel
level in real time; get maintenance reminders by mileage or date; read check-engine trouble codes and have AI explain
them; ask a voice assistant about traffic rules, nearby gas stations or the weather; and see live driving data on
the lock screen, Dynamic Island and the CarPlay dashboard. Try it without an adapter in demo mode. Works with most
gasoline cars with an OBD-II port. Open source. Not affiliated with Mazda Motor Corporation.

**Keywords:** obd2,obd,elm327,car dashboard,maintenance,check engine,diagnostic,carplay,bluetooth,oil change

## App Review notes (App Store Connect → App Review Information)

> The app reads live data from a Bluetooth LE OBD-II adapter plugged into a car. Since reviewers won't have one,
> the app starts in **Demo mode** (Ajustes → Modo demo, on by default) with a simulated drive: the dashboard,
> maintenance, diagnostics (sample code P0420) and the drive Live Activity all work without hardware.
> The assistant (Asistente tab, or "Explicar con IA" in Diagnóstico) uses our server and needs internet; no
> sign-in is required. The app does not use CarPlay templates in this version. Language: Spanish.

No demo account is needed.

## App Store "App Privacy" answers

- Data collected: **User Content → Other User Content** (assistant questions). Linked to user: **No**. Used for tracking: **No**. Purpose: **App Functionality**.
- **Identifiers → Device ID**: a random per-install id (not IDFA). Linked to user: No. Tracking: No. Purpose: App Functionality.
- Everything else (vehicle data, maintenance, profile): not collected (stays on device).

## Google Play "Data safety" answers

- Data shared with third parties: **Yes** — "App interactions / Other user-generated content" (assistant questions) shared with Anthropic to provide the feature.
- Data collected: assistant questions (optional, not required to use the app), device or other IDs (random install id).
- Encrypted in transit: **Yes** (HTTPS). Users can request deletion: deleting the app removes local data; server data is in-memory and not retained.
- Not collected: location, personal info, financial info, contacts, photos, health.

## Google Play extras

- Short description (80): `Datos en vivo de tu carro por OBD-II, mantenimiento y diagnóstico con IA.`
- Feature graphic 1024×500: `docs/store/android/feature.png`
- Phone screenshots: reuse `docs/store/ios/*.png` (Play accepts up to 3840 px; or capture on an Android emulator).
- Permissions declaration: Bluetooth (connect/scan, `neverForLocation`), microphone (voice questions).
