# Voix française de la campagne

Les huit répliques utilisent **Microsoft Vivienne Multilingual Neural**, en
français de France (`fr-FR-VivienneMultilingualNeural`). Elles remplacent les
anciens rendus Kokoro / ff_siwis. Il s'agit d'une voix de synthèse, et non de
l'enregistrement d'une comédienne pour ce jeu.

Chaque réplique est prononcée d'un seul tenant : aucune concaténation de phrases,
aucun changement artificiel de hauteur et aucun filtre radio métallique. Le
débit est réglé à −2 %. Les fichiers sont normalisés à −18 LUFS avec une limite
de crête à −2 dBTP, puis convertis en WAV PCM mono 16 bits / 24 kHz. Les durées
et les niveaux mesurés sont consignés dans `synthesis.json`.

- Voix et langues Microsoft : https://learn.microsoft.com/azure/ai-services/speech-service/language-support?tabs=tts
- Client de génération : https://github.com/Migushthe2nd/MsEdgeTTS (MIT).
- Conversion audio : https://ffmpeg.org/ ; outil local ffmpeg-static.
- Textes : dialogues originaux de la campagne HELIX, sans imitation de personne.

Le jeu lit directement les huit WAV, sans connexion nécessaire. La génération
utilise le service Microsoft Read Aloud ; seules les répliques à prononcer lui
sont transmises. Les sous-titres suivent la durée réelle des fichiers. La pause
suspend la lecture, et le décor s'atténue pendant les messages.

Régénération depuis la racine : `powershell -File art/audio/render_briefing.ps1`.
Node.js, msedge-tts 2.1.1 et ffmpeg-static 5.3.0 sont utilisés dans `.tools/voice`.
Le script attend huit fichiers complets et vérifie leurs niveaux avant de
remplacer les assets. Il conserve une copie des fichiers précédents dans le
dossier de travail `.tools/voice/vivienne/<date>/previous`. Une génération
interrompue ne remplace pas les voix du jeu. Réimporter les WAV dans Godot après
génération.
