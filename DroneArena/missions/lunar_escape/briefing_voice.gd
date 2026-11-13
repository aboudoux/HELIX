extends AudioStreamPlayer
## French Vivienne neural voice, pre-rendered to offline WAV files (24 kHz).
const LINES := {
	"arrival":"CONTRÔLE MISSION · Vous arrivez à Karen. La base n'émet plus aucun signal depuis quarante-huit heures.",
	"mission":"CONTRÔLE MISSION · Retrouvez les survivants et récupérez le journal de bord. Votre équipe attend votre rapport.",
	"drone":"CONTRÔLE MISSION · Un drone bloque le couloir. Visez avec la souris, tirez avec le clic gauche et rechargez avec R.",
	"search":"CONTRÔLE MISSION · Le passage est libre. Cherchez le journal de bord dans les quartiers sud-ouest de Karen.",
	"log":"JOURNAL RÉCUPÉRÉ · Le journal confirme une évacuation vers l'infirmerie. Retrouvez le registre des survivants.",
	"survivors":"CONTRÔLE MISSION · Des survivants ont rejoint les abris de Tycho. Une mécanicienne nommée Lina est restée dans l'atelier. Retrouvez-la.",
	"lina":"LINA · Enfin quelqu'un ! Je suis bloquée dans l'atelier de Tycho. Rétablissez le courant et venez me chercher.",
	"together":"LINA · Merci ! Le journal de Karen est avec vous ? Alors on peut encore les sauver. Je prépare le blindé. On rentre ensemble."
}

func _ready() -> void:
	volume_db = -2.0
	max_polyphony = 1

func play_line(text: String) -> float:
	stop()
	for key in LINES:
		if LINES[key]!=text: continue
		stream = load("res://audio/voice/"+key+".wav")
		if stream!=null:
			play()
			return stream.get_length()+0.25
	return 0.0
