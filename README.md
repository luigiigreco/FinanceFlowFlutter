# Finance Flow

Applicazione mobile multipiattaforma per la gestione delle finanze personali, il controllo del budget e il monitoraggio delle scadenze finanziarie, sviluppata con Flutter e integrata con Google Firebase.

---

## Indice

- [Panoramica del Progetto](#panoramica-del-progetto)
- [Funzionalita Principali](#funzionalita-principali)
  - [Autenticazione e Profilo Utente](#autenticazione-e-profilo-utente)
  - [Gestione Transazioni e Saldo](#gestione-transazioni-e-saldo)
  - [Dashboard Analitica e Budgeting](#dashboard-analitica-e-budgeting)
  - [Promemoria, Notifiche e Avvisi](#promemoria-notifiche-e-avvisi)
- [Architettura della Codebase](#architettura-della-codebase)
- [Modello Dati (Cloud Firestore)](#modello-dati-cloud-firestore)
- [Stack Tecnologico](#stack-tecnologico)
- [Prerequisiti](#prerequisiti)
- [Installazione e Configurazione](#installazione-e-configurazione)
- [Esecuzione e Build](#esecuzione-e-build)
- [Linee Guida di Sviluppo](#linee-guida-di-sviluppo)

---

## Panoramica del Progetto

Finance Flow e una soluzione mobile progettata per offrire un controllo completo e trasparente delle proprie finanze quotidiane. L'applicazione consente agli utenti di registrare entrate e uscite con categorie specifiche, verificare in tempo reale il saldo disponibile, analizzare i flussi monetari tramite grafici comparativi, impostare limiti di spesa periodici (budget) e ricevere notifiche tempestive per scadenze di pagamenti o bollette.

Grazie all'integrazione con Firebase Authentication e Cloud Firestore, tutti i dati sono sincronizzati nel cloud, garantendo persistenza, coerenza e isolamento completo delle informazioni per ciascun utente registrato.

---

## Funzionalita Principali

### Autenticazione e Profilo Utente
- Registrazione e accesso tramite credenziali email e password gestite da Firebase Authentication.
- Gestione automatica dello stato di sessione con ascolto reattivo tramite StreamBuilder.
- Separazione dei dati a livello utente per garantire riservatezza e sicurezza.
- Funzione di disconnessione (logout) accessibile direttamente dalla barra dell'applicazione.

### Gestione Transazioni e Saldo
- Calcolo automatico e aggiornamento dinamico del saldo totale.
- Registrazione rapida di nuove transazioni specificando importo, tipologia (entrata o uscita) e categoria.
- Categorie predefinite: Stipendio, Alimentari, Shopping, Spese Mediche, Regali, Bollette, Tutte le Spese.
- Visualizzazione cronologica decrescente delle movimentazioni con formattazione europea di data e ora (`dd/MM/yyyy HH:mm`).
- Distinzione visiva immediata tra entrate (verde con segno +) e uscite (rosso con segno -).
- Eliminazione rapida di singole transazioni tramite gesto di scorrimento (swipe-to-dismiss) corredato da dialogo di conferma.

### Dashboard Analitica e Budgeting
- Visualizzazione grafica interattiva a barre (tramite libreria `fl_chart`) per il confronto diretto tra entrate e uscite aggregate per ciascuna categoria.
- Tooltip descrittivi al tocco sulle barre per la consultazione dettagliata degli importi.
- Creazione e monitoraggio di budget di spesa con configurazione di nome, importo target, finestra temporale (data inizio e fine) e categoria associata.
- Calcolo automatico della spesa progressiva associata a ciascun budget con indicatore lineare di avanzamento.
- Rilevamento visivo automatico del superamento del budget e di budget scaduti.
- Rimozione sicura dei budget con conferma interattiva.

### Promemoria, Notifiche e Avvisi
- Creazione di promemoria finanziari con titolo e data di scadenza (ad esempio pagamenti programmati o bollette in scadenza).
- Programmazione automatica di notifiche locali sul dispositivo tramite `flutter_local_notifications` e gestione fusi orari con `timezone`.
- Notifiche inviate a due giorni dalla scadenza e alla data esatta dell'evento.
- Generazione automatica di avvisi persistenti memorizzati nel database per gli eventi in scadenza e scaduti.
- Raggruppamento e categorizzazione visiva degli avvisi con codifica cromatica in base alla priorita (arancione per imminenti, rosso per scaduti).
- Eliminazione gestuale di promemoria e avvisi.

---

## Architettura della Codebase

La logica applicativa risiede nella cartella `lib/` ed e organizzata in moduli distinti:

```
lib/
├── firebase_options.dart      # Configurazione generata da FlutterFire per Android e iOS
├── main.dart                  # Punto di ingresso dell'app, inizializzazione Firebase e routing
├── login_screen.dart          # Schermata di autenticazione (login e registrazione)
├── home_screen.dart           # Dashboard principale: saldo, lista transazioni e navigazione
├── dashboard_screen.dart      # Grafici analitici fl_chart e gestione/progressione dei budget
└── notifications_screen.dart  # Schedulazione notifiche locali, promemoria e avvisi di scadenza
```

### Ruolo dei File Principali

- `lib/main.dart`: Configura il punto di ingresso asincrono, assicura il binding dei widget, inizializza Firebase con `DefaultFirebaseOptions.currentPlatform` e definisce il tema globale basato su Material Design 3.
- `lib/login_screen.dart`: Gestisce i campi di testo per credenziali utente, la validazione, l'integrazione con `FirebaseAuth.signInWithEmailAndPassword` e `createUserWithEmailAndPassword`, e il feedback visivo tramite SnackBar.
- `lib/home_screen.dart`: Fornisce il contenitore principale con `BottomNavigationBar` (Home, Dashboard, Notifiche), interroga la sotto-collezione `transazioni` su Firestore, calcola il saldo e gestisce i modali di inserimento ed eliminazione.
- `lib/dashboard_screen.dart`: Aggrega le entrate e uscite per categoria generando la struttura `BarChartGroupData`, gestisce la collezione `budget` e ricalcola il parametro `usato` in base alle uscite effettive registrate nell'intervallo temporale.
- `lib/notifications_screen.dart`: Inizializza il plugin `FlutterLocalNotificationsPlugin`, imposta i canali Android, programma notifiche con `zonedSchedule` e gestisce la persistenza degli avvisi su Firestore.

---

## Modello Dati (Cloud Firestore)

I dati dell'applicazione sono strutturati gerarchicamente sotto la collezione radice `users`, assicurando la separazione logica per singolo identificativo utente (`userId`):

### 1. Sotto-collezione `transazioni`
Percorso: `users/{userId}/transazioni/{transactionId}`
- `tipo` (String): Tipologia della transazione (`entrata` oppure `uscita`).
- `categoria` (String): Categoria merceologica (es. `Stipendio`, `Alimentari`, `Bollette`).
- `importo` (double): Valore monetario (positivo per entrate, negativo per uscite).
- `data` (Timestamp): Data e ora della transazione.

### 2. Sotto-collezione `budget`
Percorso: `users/{userId}/budget/{budgetId}`
- `nome` (String): Denominazione descrittiva del budget.
- `importo` (double): Soglia massima allocata.
- `usato` (double): Spesa effettiva calcolata sulle transazioni correlate.
- `tag` (String): Categoria monitorata dal budget.
- `data_inizio` (Timestamp): Inizio del periodo di validita.
- `data_fine` (Timestamp): Fine del periodo di validita.
- `data_creazione` (Timestamp): Timestamp di generazione del record.

### 3. Sotto-collezione `promemoria`
Percorso: `users/{userId}/promemoria/{promemoriaId}`
- `title` (String): Oggetto o causale del promemoria.
- `scadenza` (Timestamp): Data prefissata per la scadenza.
- `createdAt` (Timestamp): Timestamp di creazione.

### 4. Sotto-collezione `avvisi`
Percorso: `users/{userId}/avvisi/{avvisoId}`
- `title` (String): Titolo dell'avviso generato (es. "Promemoria in scadenza", "Promemoria scaduto").
- `body` (String): Testo descrittivo dell'avviso.
- `createdAt` (Timestamp): Data e ora della generazione dell'avviso.

---

## Stack Tecnologico

| Tecnologia / Pacchetto | Versione | Utilizzo Principale |
| :--- | :--- | :--- |
| **Flutter SDK** | ^3.5.4 | Framework UI multipiattaforma |
| **Dart** | ^3.5.4 | Linguaggio di programmazione |
| **firebase_core** | ^2.13.0 | Bootstrap e connessione ai servizi Firebase |
| **firebase_auth** | ^4.8.1 | Gestione autenticazione utenti ed emissione token |
| **cloud_firestore** | ^4.10.0 | Database NoSQL documentale in tempo reale |
| **firebase_storage** | ^11.4.0 | Storage di file e risorse multimediali |
| **firebase_messaging** | ^14.8.0 | Notifiche push cloud (FCM) |
| **firebase_analytics** | ^10.10.7 | Monitoraggio e telemetria d'uso dell'applicazione |
| **fl_chart** | ^0.69.0 | Rendering di grafici a barre interattivi e personalizzabili |
| **flutter_local_notifications** | ^13.0.0 | Gestione e pianificazione notifiche locali su dispositivo |
| **timezone** | ^0.9.0 | Supporto calcoli orari e schedulazione precisa per data/ora |
| **intl** | ^0.17.0 | Internazionalizzazione e formattazione date e valute |
| **flutter_launcher_icons** | ^0.14.1 | Generazione automatizzata delle icone applicative native |

---

## Prerequisiti

Prima di compilare ed eseguire il progetto, assicurarsi di disporre dei seguenti strumenti installati nel proprio ambiente:

- Flutter SDK (versione 3.24.x o superiore raccomandata, compatibile con Dart SDK ^3.5.4).
- Android Studio con Android SDK e Build-Tools configurati (per target Android).
- Xcode 15 o superiore e CocoaPods (per target iOS, richiesto ambiente macOS).
- Progetto Firebase configurato sulla Firebase Console con abilitati:
  - Authentication (Provider Email/Password)
  - Cloud Firestore Database
  - Firebase Cloud Messaging (opzionale)

---

## Installazione e Configurazione

### 1. Clonare il repository

```bash
git clone https://github.com/luigiigreco/FinanceFlowFlutter.git
cd FinanceFlowFlutter
```

### 2. Installare i pacchetti e le dipendenze

```bash
flutter pub get
```

### 3. Configurazione di Firebase

Il repository include i riferimenti di base in `lib/firebase_options.dart`. Qualora si desideri collegare una propria istanza Firebase:

1. Installare la CLI di Firebase e la CLI di FlutterFire:
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```
2. Effettuare il login ed eseguire la configurazione:
   ```bash
   firebase login
   flutterfire configure
   ```
3. Verificare che i file di configurazione nativi siano posizionati correttamente:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

### 4. Generazione delle Icone Applicative (Opzionale)

Se necessario rigenerare le icone per le piattaforme native:

```bash
flutter pub run flutter_launcher_icons
```

---

## Esecuzione e Build

### Avvio in modalita Debug

Collegare un dispositivo fisico o avviare un emulatore, quindi eseguire:

```bash
flutter run
```

Specificando facoltativamente la piattaforma target:

```bash
# Esecuzione su dispositivo Android
flutter run -d android

# Esecuzione su simulatore iOS
flutter run -d ios
```

### Compilazione per il rilascio

```bash
# Compilazione APK Android
flutter build apk --release

# Compilazione App Bundle Android (AAB)
flutter build appbundle --release

# Compilazione per iOS (richiede macOS e Xcode)
flutter build ipa --release
```

---

## Linee Guida di Sviluppo

- **Analisi Statica**: Eseguire periodicamente il linter per mantenere lo standard di qualita del codice:
  ```bash
  flutter analyze
  ```
- **Test Unitari e di Widget**: Eseguire la suite di test presente in `test/`:
  ```bash
  flutter test
  ```
- **Convenzioni di Stile**: Rispettare le convenzioni ufficiali Dart e le regole indicate in `analysis_options.yaml`.
