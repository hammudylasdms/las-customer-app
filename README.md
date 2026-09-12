# LAS Customer – Flutter-Stand 0.3.0

**Status: Entwicklungsstand, keine installierbare oder freigegebene iPhone-App.**

Die App lädt das echte Kundenportal unter `https://dms.lastoptechnik.com/customer`. Das ist der im vorhandenen Backend konfigurierte Standard; der produktive Ursprung ist vor Gerätests abzugleichen. Keine Beispieldaten, keine Mitarbeiter-API, keine kopierte Geschäftslogik.

## Enthalten

- Flutter-Oberfläche mit Originalportal in der System-WebView; vorhandenes HTML/CSS, Logos und Schriften kommen weiterhin vom Portal.
- Native Zurück-/Startnavigation, Ladeanzeige, Fehleransicht, Abdeckung beim Wechsel in den Hintergrund.
- HTTPS-Ursprungsprüfung, Trennung externer Links und eingeschränkte App-Link-Ziele.
- Bestehende Kundensitzung bleibt als HttpOnly-Cookie in der WebView. Die App liest keine Passwörter oder Sitzungstokens aus.
- Optionaler Firebase-Push-Entwurf, standardmäßig ausgeschaltet. Dazu gehört der separate Backend-Adapter im Nachbarordner.
- Erfolgsmeldung für Push erst nach bestätigter Backend-Anmeldung. Eigenes Menü zum Aktivieren/Deaktivieren; fehlender Login, verweigerte Berechtigung und unbestätigte Änderungen werden getrennt gemeldet.
- Die Rückmeldung aus der WebView wird einem einzelnen ausstehenden Aufruf zugeordnet. Fremde oder verspätete Antworten werden verworfen; Anfragen enden bei Zeitüberschreitung oder Seitenwechsel.
- Manuell startbarer iOS-Simulator-Build für einen GitHub-Mac-Runner vorbereitet. Anleitung: `CLOUD-BUILD.md`. Noch kein Cloud-Lauf erfolgt.

## Noch offen

- Paketauflösung und Flutter-Codeanalyse sind abgeschlossen; alle vier Flutter-Testgruppen bestehen. Siehe `PRUEFBERICHT.md`.
- iOS-Build, Signierung, Simulator-/iPhone-Tests und TestFlight. Mac/Xcode und Apple-Developer-Zugang sind laut Rückmeldung noch nicht vorhanden.
- Fotogalerie und dauerhafte Push-Gerätebindung sind als getesteter Backend-Patch enthalten, aber noch nicht auf dem Server installiert. Fotos verwenden ausdrücklich veröffentlichte Auftragsanhänge.
- Zahlungstests: eingebettetes Checkout kann HTTPS-Frames laden. Externe Zahlungsseiten öffnen im Systembrowser, dessen Cookie-Sitzung separat ist. Rückkehr, 3-D Secure und Abschlussanzeige müssen mit den tatsächlich eingesetzten Anbietern im Testmodus fertiggestellt werden. Keine App-seitige Bestätigung einer Zahlung.
- Dokument-/Videoanzeige und Downloads auf echten Geräten, insbesondere PDFs unter Android.
- Bestehende UAE-PASS-Dokumentsignaturlinks öffnen im Systembrowser. UAE-PASS-App-Login und native Rückleitungen bleiben offen.
- App-Links benötigen Domain-Zuordnung mit echten Team-/Bundle-IDs. Eingehende Ziele werden im Dart-Code bereits eingeschränkt.
- Push benötigt Firebase-/APNs-Konfiguration. Der neue Adapter registriert Geräte bis zu 90 Tage unabhängig vom 30-Minuten-Portalablauf. Alle mitgelieferten Backend-Änderungen müssen gemeinsam integriert werden.

## Entwicklung

Mit einem eingerichteten Flutter-SDK im Projektordner:

```sh
flutter create --platforms=ios,android --org com.lastoptechnik --project-name las_customer .
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=PORTAL_ORIGIN=https://dms.lastoptechnik.com
```

Die iOS-/Android-Projektdateien sind bereits erzeugt; `flutter create` ist nur zur Wiederherstellung nötig. Die Organisations-/Bundle-ID ist vor Veröffentlichung abschließend festzulegen. Push erst mit konfiguriertem Firebase, APNs und installiertem Backend-Adapter über `--dart-define=ENABLE_PUSH=true` einschalten. Ohne diese Option wird Firebase nicht initialisiert. Die App-Symbole sind noch Flutter-Standardgrafiken und müssen vor einer Veröffentlichung durch die endgültigen LAS-App-Symbole ersetzt werden.

## Native Einrichtung für Push und App-Links

Firebase-Projektdateien für die endgültigen App-IDs erzeugen und plattformspezifisch einbinden. Unter iOS Push-Capability und benötigte Background Modes einrichten; APNs-Schlüssel ausschließlich in Firebase/serverseitig hinterlegen. `FirebaseMessagingAutoInitEnabled` in Info.plist zunächst auf false setzen. Unter Android `firebase_messaging_auto_init_enabled` und `firebase_analytics_collection_enabled` auf false setzen. Die App fordert die Benachrichtigungsberechtigung erst über die Glocke an.

Für Universal Links Associated Domains und die serverseitige apple-app-site-association passend zur echten Apple-Team-ID einrichten. Android benötigt passende intent-filter und assetlinks.json mit dem echten Signierzertifikat. Bei Verwendung von app_links den Flutter-eigenen Deep-Link-Handler nach dessen Paketdokumentation deaktivieren. Keine Zuordnungsdateien mit erfundenen Signierdaten veröffentlichen.

Referenzen: [Flutter iOS](https://docs.flutter.dev/platform-integration/ios), [WebView](https://pub.dev/packages/webview_flutter), [Firebase](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [App Links](https://pub.dev/packages/app_links).
