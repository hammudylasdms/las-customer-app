# iOS-Testbuild ohne eigenen Mac

Der manuell startbare GitHub-Actions-Ablauf ist vorbereitet, aber **noch nicht ausgeführt**. Es wurde kein Konto oder Repository angelegt und nichts hochgeladen.

## Was der Ablauf liefert

Ein Mac-Runner lädt die festgelegte Flutter-Version, prüft Formatierung und Code, führt die Flutter-Tests aus und baut eine unsignierte Simulator-App. Das Ergebnis wird als Archiv für sieben Tage im Repository bereitgestellt. Push bleibt ausgeschaltet; Firebase- oder Apple-Schlüssel sind für diesen Schritt nicht vorgesehen.

Das ist ein Build-Test, kein TestFlight-Paket. Das Ergebnis lässt sich nicht direkt auf einem iPhone installieren. Es beweist auch keine erfolgreiche Zahlung oder Push-Zustellung.

## Vorbereitung und Start

1. Ein GitHub-Konto und ein privates Repository für den App-Quellcode anlegen.
2. Den **Inhalt des Ordners las_customer** als Repository-Hauptverzeichnis übernehmen, einschließlich `.github/workflows/ios-simulator.yml`. Nicht den gesamten Entpackordner als zusätzliche übergeordnete Ebene hochladen. Lokale Caches, Build-Verzeichnisse und Schlüssel gehören nicht hinein.

   Das zusätzliche Archiv `LAS-Customer-GitHub.zip` enthält genau diesen Repository-Inhalt ohne übergeordneten Ordner und ohne Backend-Dateien.
3. GitHub Actions im Repository verfügbar machen und vorhandenes Nutzungskontingent prüfen.
4. Unter Actions den Ablauf **iOS simulator build** auswählen und mit **Run workflow** starten. Der Portal-Ursprung kann beim Start gesetzt werden; er enthält nur HTTPS, Host und optional Port.
5. Nach erfolgreichem Lauf das Artefakt **LAS-Customer-simulator** herunterladen. Bei einem Fehler zuerst das Protokoll des fehlgeschlagenen Schritts auswerten.

Der Ablauf wird nur manuell gestartet und veröffentlicht nichts im App Store. Für spätere iPhone-/TestFlight-Builds werden Apple-Team, endgültige App-ID und Signierung separat eingerichtet.

Der gleiche Ablauf kann auf einem eingerichteten Mac mit `bash scripts/check_ios.sh` gestartet werden.

Quellen: [Flutter iOS-Veröffentlichung](https://docs.flutter.dev/deployment/ios), [GitHub macOS-Runner](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md), [Checkout](https://github.com/actions/checkout), [Artefakte](https://github.com/actions/upload-artifact).
