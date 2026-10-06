#!/usr/bin/env python3
"""Genera la web pública de la app (GitHub Pages, carpeta `docs/`): política de privacidad y
soporte en los seis idiomas, y escribe sus URL en la ficha de fastlane.

    python3 scripts/app_store/web.py
"""
import html
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOCS = os.path.join(ROOT, "docs")
METADATA = os.path.join(ROOT, "fastlane", "metadata")
BASE_URL = "https://sergiogd7.github.io/closetFinder-iOS"
ISSUES = "https://github.com/SergioGD7/closetFinder-iOS/issues"
NEW_ISSUE = ISSUES + "/new"
UPDATED = {"es": "6 de octubre de 2026", "en": "October 6, 2026", "fr": "6 octobre 2026",
           "de": "6. Oktober 2026", "it": "6 ottobre 2026", "pt": "6 de outubro de 2026"}

# Idioma de la web → carpeta de fastlane.
LANGUAGES = [("es", "Español", "es-ES"), ("en", "English", "en-US"), ("fr", "Français", "fr-FR"),
             ("de", "Deutsch", "de-DE"), ("it", "Italiano", "it"), ("pt", "Português", "pt-BR")]

PRIVACY = {
"es": {
"title": "Política de privacidad", "updated": "Última actualización",
"intro": "Closet Finder es una app para iPhone y iPad que te ayuda a saber qué ropa tienes y dónde la guardas. Aquí se explica qué hace la app con tus datos. En resumen: no recopilamos ningún dato.",
"sections": [
("No recopilamos datos", "La app no tiene cuentas, anuncios, analítica ni rastreo. El desarrollador no recibe, vende ni comparte ninguna información sobre ti ni sobre tu ropa."),
("Dónde se guardan tus datos", "Las prendas, fotos, ubicaciones, medidas, looks y maletas se guardan en tu dispositivo. Si usas iCloud, se sincronizan con tu base de datos privada de iCloud, a la que solo tú tienes acceso y que Apple gestiona según su política de privacidad. El desarrollador no puede ver esos datos."),
("Cámara y fotos", "La cámara y la fototeca solo se usan cuando tú lo pides, para fotografiar prendas y etiquetas. Al elegir fotos, la app solo accede a las que seleccionas. El recorte del fondo, el color y la lectura de etiquetas se hacen en el propio dispositivo."),
("Apple Intelligence", "La búsqueda inteligente y la lectura de etiquetas usan el modelo de Apple Intelligence que funciona en el dispositivo. El texto no sale de tu iPhone o iPad."),
("Destino de las maletas", "Si escribes el destino de un viaje, ese texto se envía a Apple Maps para localizarlo y saber en qué hemisferio está. Apple lo trata según su política de privacidad. No se envía nada más."),
("Copias de seguridad", "Solo se crea un archivo de copia de seguridad cuando tú lo exportas, y se guarda donde tú elijas."),
("Cómo borrar tus datos", "Puedes borrar prendas y cualquier otro elemento desde la app. Para borrar la copia de iCloud, ve a Ajustes del iPhone › tu nombre › iCloud › Gestionar almacenamiento › Closet Finder."),
("Menores", "La app no recopila datos de nadie, tampoco de menores."),
("Cambios", "Si esta política cambia, la nueva versión se publicará en esta página con su fecha."),
("Contacto", 'Si tienes cualquier duda, <a href="{issues}">abre una incidencia en GitHub</a>. Responsable: Sergio González Díaz.'),
]},
"en": {
"title": "Privacy Policy", "updated": "Last updated",
"intro": "Closet Finder is an iPhone and iPad app that helps you know what clothes you have and where you keep them. This page explains what the app does with your data. In short: we don’t collect any data.",
"sections": [
("We don’t collect data", "The app has no accounts, ads, analytics or tracking. The developer doesn’t receive, sell or share any information about you or your clothes."),
("Where your data is stored", "Your items, photos, places, measurements, looks and suitcases are stored on your device. If you use iCloud, they sync with your private iCloud database, which only you can access and which Apple manages under its privacy policy. The developer can’t see this data."),
("Camera and photos", "The camera and photo library are only used when you ask, to photograph clothes and labels. When you choose photos, the app only accesses the ones you select. Background removal, color detection and label reading happen on the device."),
("Apple Intelligence", "Smart search and label reading use Apple Intelligence’s on-device model. The text never leaves your iPhone or iPad."),
("Trip destinations", "If you enter a trip destination, that text is sent to Apple Maps to locate it and know which hemisphere it’s in. Apple handles it under its privacy policy. Nothing else is sent."),
("Backups", "A backup file is only created when you export one, and it’s saved wherever you choose."),
("How to delete your data", "You can delete items and anything else from the app. To delete the iCloud copy, go to iPhone Settings › your name › iCloud › Manage Storage › Closet Finder."),
("Children", "The app doesn’t collect data from anyone, including children."),
("Changes", "If this policy changes, the new version will be published on this page with its date."),
("Contact", 'If you have any questions, <a href="{issues}">open an issue on GitHub</a>. Data controller: Sergio González Díaz.'),
]},
"fr": {
"title": "Politique de confidentialité", "updated": "Dernière mise à jour",
"intro": "Closet Finder est une app pour iPhone et iPad qui vous aide à savoir quels vêtements vous avez et où vous les rangez. Cette page explique ce que fait l’app de vos données. En bref : nous ne collectons aucune donnée.",
"sections": [
("Nous ne collectons aucune donnée", "L’app n’a ni compte, ni publicité, ni outil d’analyse, ni suivi. Le développeur ne reçoit, ne vend et ne partage aucune information sur vous ou vos vêtements."),
("Où sont stockées vos données", "Vos vêtements, photos, emplacements, mesures, looks et valises sont stockés sur votre appareil. Si vous utilisez iCloud, ils sont synchronisés avec votre base de données iCloud privée, à laquelle vous seul avez accès et qu’Apple gère selon sa politique de confidentialité. Le développeur ne peut pas voir ces données."),
("Appareil photo et photos", "L’appareil photo et la photothèque ne sont utilisés qu’à votre demande, pour photographier vêtements et étiquettes. Quand vous choisissez des photos, l’app n’accède qu’à celles que vous sélectionnez. Le détourage, la couleur et la lecture des étiquettes se font sur l’appareil."),
("Apple Intelligence", "La recherche intelligente et la lecture des étiquettes utilisent le modèle Apple Intelligence qui fonctionne sur l’appareil. Le texte ne quitte pas votre iPhone ou iPad."),
("Destination des valises", "Si vous saisissez la destination d’un voyage, ce texte est envoyé à Apple Plans pour la localiser et savoir dans quel hémisphère elle se trouve. Apple le traite selon sa politique de confidentialité. Rien d’autre n’est envoyé."),
("Sauvegardes", "Un fichier de sauvegarde n’est créé que lorsque vous l’exportez, et il est enregistré où vous le choisissez."),
("Supprimer vos données", "Vous pouvez supprimer vêtements et autres éléments depuis l’app. Pour supprimer la copie iCloud : Réglages de l’iPhone › votre nom › iCloud › Gérer le stockage › Closet Finder."),
("Enfants", "L’app ne collecte de données sur personne, y compris les enfants."),
("Modifications", "Si cette politique change, la nouvelle version sera publiée sur cette page avec sa date."),
("Contact", 'Pour toute question, <a href="{issues}">ouvrez un ticket sur GitHub</a>. Responsable : Sergio González Díaz.'),
]},
"de": {
"title": "Datenschutzerklärung", "updated": "Zuletzt aktualisiert",
"intro": "Closet Finder ist eine App für iPhone und iPad, mit der du weißt, welche Kleidung du hast und wo du sie aufbewahrst. Hier steht, was die App mit deinen Daten macht. Kurz gesagt: Wir erfassen keine Daten.",
"sections": [
("Wir erfassen keine Daten", "Die App hat keine Konten, keine Werbung, keine Analyse und kein Tracking. Der Entwickler erhält, verkauft oder teilt keine Informationen über dich oder deine Kleidung."),
("Wo deine Daten gespeichert sind", "Deine Kleidungsstücke, Fotos, Orte, Maße, Looks und Koffer werden auf deinem Gerät gespeichert. Wenn du iCloud nutzt, werden sie mit deiner privaten iCloud-Datenbank synchronisiert, auf die nur du Zugriff hast und die Apple gemäß seiner Datenschutzrichtlinie verwaltet. Der Entwickler kann diese Daten nicht sehen."),
("Kamera und Fotos", "Kamera und Fotomediathek werden nur auf deinen Wunsch verwendet, um Kleidung und Etiketten zu fotografieren. Bei der Fotoauswahl greift die App nur auf die ausgewählten Fotos zu. Freistellen, Farberkennung und Etikettenlesen passieren auf dem Gerät."),
("Apple Intelligence", "Die intelligente Suche und das Etikettenlesen nutzen das Apple-Intelligence-Modell auf dem Gerät. Der Text verlässt dein iPhone oder iPad nicht."),
("Reiseziele", "Wenn du ein Reiseziel eingibst, wird dieser Text an Apple Karten gesendet, um es zu finden und die Erdhalbkugel zu bestimmen. Apple behandelt ihn gemäß seiner Datenschutzrichtlinie. Sonst wird nichts gesendet."),
("Backups", "Eine Backup-Datei wird nur erstellt, wenn du sie exportierst, und dort gespeichert, wo du es wählst."),
("Daten löschen", "Du kannst Kleidungsstücke und alles andere in der App löschen. Die iCloud-Kopie löschst du unter iPhone-Einstellungen › dein Name › iCloud › Speicher verwalten › Closet Finder."),
("Kinder", "Die App erfasst von niemandem Daten, auch nicht von Kindern."),
("Änderungen", "Wenn sich diese Erklärung ändert, wird die neue Fassung mit Datum auf dieser Seite veröffentlicht."),
("Kontakt", 'Bei Fragen <a href="{issues}">erstelle ein Issue auf GitHub</a>. Verantwortlich: Sergio González Díaz.'),
]},
"it": {
"title": "Informativa sulla privacy", "updated": "Ultimo aggiornamento",
"intro": "Closet Finder è un’app per iPhone e iPad che ti aiuta a sapere quali vestiti hai e dove li tieni. Qui spieghiamo cosa fa l’app con i tuoi dati. In breve: non raccogliamo alcun dato.",
"sections": [
("Non raccogliamo dati", "L’app non ha account, pubblicità, analisi né tracciamento. Lo sviluppatore non riceve, vende né condivide alcuna informazione su di te o sui tuoi vestiti."),
("Dove sono salvati i tuoi dati", "Capi, foto, posti, misure, look e valigie sono salvati sul tuo dispositivo. Se usi iCloud, si sincronizzano con il tuo database iCloud privato, a cui solo tu hai accesso e che Apple gestisce secondo la sua informativa sulla privacy. Lo sviluppatore non può vedere questi dati."),
("Fotocamera e foto", "La fotocamera e la libreria foto si usano solo quando lo chiedi, per fotografare capi ed etichette. Quando scegli le foto, l’app accede solo a quelle selezionate. Rimozione dello sfondo, colore e lettura delle etichette avvengono sul dispositivo."),
("Apple Intelligence", "La ricerca intelligente e la lettura delle etichette usano il modello di Apple Intelligence sul dispositivo. Il testo non lascia il tuo iPhone o iPad."),
("Destinazione delle valigie", "Se scrivi la destinazione di un viaggio, quel testo viene inviato a Mappe di Apple per localizzarla e sapere in quale emisfero si trova. Apple lo tratta secondo la sua informativa sulla privacy. Non viene inviato nient’altro."),
("Backup", "Un file di backup viene creato solo quando lo esporti, e viene salvato dove scegli tu."),
("Come cancellare i tuoi dati", "Puoi eliminare capi e qualsiasi altro elemento dall’app. Per eliminare la copia su iCloud: Impostazioni dell’iPhone › il tuo nome › iCloud › Gestisci spazio › Closet Finder."),
("Minori", "L’app non raccoglie dati di nessuno, nemmeno dei minori."),
("Modifiche", "Se questa informativa cambia, la nuova versione sarà pubblicata in questa pagina con la sua data."),
("Contatti", 'Per qualsiasi domanda, <a href="{issues}">apri una segnalazione su GitHub</a>. Titolare: Sergio González Díaz.'),
]},
"pt": {
"title": "Política de privacidade", "updated": "Última atualização",
"intro": "O Closet Finder é um app para iPhone e iPad que ajuda você a saber quais roupas tem e onde as guarda. Esta página explica o que o app faz com seus dados. Em resumo: não coletamos nenhum dado.",
"sections": [
("Não coletamos dados", "O app não tem contas, anúncios, análises nem rastreamento. O desenvolvedor não recebe, vende nem compartilha nenhuma informação sobre você ou suas roupas."),
("Onde seus dados ficam", "Peças, fotos, lugares, medidas, looks e malas ficam salvos no seu dispositivo. Se você usa o iCloud, eles sincronizam com seu banco de dados privado do iCloud, ao qual só você tem acesso e que a Apple gerencia segundo a política de privacidade dela. O desenvolvedor não consegue ver esses dados."),
("Câmera e fotos", "A câmera e a fototeca só são usadas quando você pede, para fotografar roupas e etiquetas. Ao escolher fotos, o app só acessa as que você seleciona. A remoção do fundo, a cor e a leitura de etiquetas acontecem no próprio dispositivo."),
("Apple Intelligence", "A busca inteligente e a leitura de etiquetas usam o modelo do Apple Intelligence que funciona no dispositivo. O texto não sai do seu iPhone ou iPad."),
("Destino das malas", "Se você escreve o destino de uma viagem, esse texto é enviado ao Apple Mapas para localizá-lo e saber em qual hemisfério está. A Apple o trata segundo a política de privacidade dela. Nada mais é enviado."),
("Backups", "Um arquivo de backup só é criado quando você o exporta, e é salvo onde você escolher."),
("Como apagar seus dados", "Você pode apagar peças e qualquer outro item pelo app. Para apagar a cópia do iCloud: Ajustes do iPhone › seu nome › iCloud › Gerenciar Armazenamento › Closet Finder."),
("Menores", "O app não coleta dados de ninguém, nem de menores."),
("Alterações", "Se esta política mudar, a nova versão será publicada nesta página com a data."),
("Contato", 'Em caso de dúvidas, <a href="{issues}">abra uma issue no GitHub</a>. Responsável: Sergio González Díaz.'),
]},
}

SUPPORT = {
"es": {
"title": "Soporte", "intro": "¿Tienes una duda o un problema? Aquí están las respuestas a las preguntas más habituales. Si no encuentras la tuya, escríbenos.",
"contact_title": "Contactar", "contact": "Abre una incidencia en GitHub, cuenta qué pasa y, si puedes, añade una captura de pantalla.", "button": "Escribir en GitHub",
"faq_title": "Preguntas frecuentes", "privacy": "Política de privacidad",
"faq": [
("¿Dónde se guardan mis datos?", "En tu dispositivo y, si usas iCloud, en tu iCloud privado. Nadie más tiene acceso."),
("Si borro la app o cambio de iPhone, ¿pierdo mi armario?", "No, si usas iCloud con el mismo Apple ID: los datos vuelven solos al instalar la app. Sin iCloud, exporta una copia en Medidas › Ajustes › Exportar copia de seguridad y recupérala desde el mismo sitio con «Restaurar desde un archivo»."),
("No se sincroniza entre el iPhone y el iPad", "Comprueba que los dos usan el mismo Apple ID y que iCloud está activado. La sincronización puede tardar unos minutos. En Medidas › Ajustes verás el estado de iCloud."),
("¿Cómo funcionan las etiquetas QR?", "En una ubicación, abre «Etiqueta QR», imprímela y pégala en la caja o el cajón. Al escanearla con la Cámara del iPhone o desde la app verás qué hay dentro."),
("El fondo de la foto no se recorta bien", "Extiende la prenda sobre un fondo liso y con buena luz. Si aun así no se recorta, la foto se guarda entera."),
("¿Puedo usar pulgadas?", "Sí. Por defecto se usa la unidad de tu región; puedes cambiarla en Medidas › Ajustes › Unidades."),
("Requisitos", "iPhone o iPad con iOS o iPadOS 17 o posterior. La búsqueda inteligente necesita un dispositivo compatible con Apple Intelligence."),
]},
"en": {
"title": "Support", "intro": "Have a question or a problem? Here are answers to the most common questions. If you can’t find yours, get in touch.",
"contact_title": "Contact", "contact": "Open an issue on GitHub, tell us what’s happening and, if you can, add a screenshot.", "button": "Write on GitHub",
"faq_title": "Frequently asked questions", "privacy": "Privacy Policy",
"faq": [
("Where is my data stored?", "On your device and, if you use iCloud, in your private iCloud. Nobody else has access."),
("If I delete the app or change iPhone, do I lose my closet?", "No, if you use iCloud with the same Apple ID: your data comes back on its own when you install the app. Without iCloud, export a backup in Measurements › Settings › Export backup and bring it back from the same place with “Restore from a file”."),
("It doesn’t sync between my iPhone and iPad", "Check that both use the same Apple ID and that iCloud is on. Syncing can take a few minutes. Measurements › Settings shows the iCloud status."),
("How do QR labels work?", "In a place, open “QR label”, print it and stick it on the box or drawer. Scan it with the iPhone Camera or from the app to see what’s inside."),
("The photo background isn’t removed well", "Lay the item flat on a plain background in good light. If it still isn’t removed, the whole photo is kept."),
("Can I use centimeters?", "Yes. Your region’s unit is used by default; you can change it in Measurements › Settings › Units."),
("Requirements", "iPhone or iPad with iOS or iPadOS 17 or later. Smart search needs a device that supports Apple Intelligence."),
]},
"fr": {
"title": "Assistance", "intro": "Une question ou un problème ? Voici les réponses aux questions les plus fréquentes. Si vous ne trouvez pas la vôtre, écrivez-nous.",
"contact_title": "Nous contacter", "contact": "Ouvrez un ticket sur GitHub, expliquez ce qui se passe et, si possible, ajoutez une capture d’écran.", "button": "Écrire sur GitHub",
"faq_title": "Questions fréquentes", "privacy": "Politique de confidentialité",
"faq": [
("Où sont stockées mes données ?", "Sur votre appareil et, si vous utilisez iCloud, dans votre iCloud privé. Personne d’autre n’y a accès."),
("Si je supprime l’app ou change d’iPhone, est-ce que je perds mon dressing ?", "Non, si vous utilisez iCloud avec le même identifiant Apple : vos données reviennent seules en installant l’app. Sans iCloud, exportez une sauvegarde dans Mesures › Réglages › Exporter une sauvegarde et récupérez-la au même endroit avec « Restaurer depuis un fichier »."),
("La synchronisation entre iPhone et iPad ne fonctionne pas", "Vérifiez que les deux utilisent le même identifiant Apple et qu’iCloud est activé. La synchronisation peut prendre quelques minutes. Mesures › Réglages affiche l’état d’iCloud."),
("Comment fonctionnent les étiquettes QR ?", "Dans un emplacement, ouvrez « Étiquette QR », imprimez-la et collez-la sur la boîte ou le tiroir. Scannez-la avec l’appareil photo de l’iPhone ou depuis l’app pour voir ce qu’il contient."),
("Le fond de la photo est mal retiré", "Posez le vêtement à plat sur un fond uni avec une bonne lumière. Si le fond n’est toujours pas retiré, la photo est conservée entière."),
("Puis-je utiliser les pouces ?", "Oui. L’unité de votre région est utilisée par défaut ; vous pouvez la changer dans Mesures › Réglages › Unités."),
("Configuration requise", "iPhone ou iPad avec iOS ou iPadOS 17 ou version ultérieure. La recherche intelligente nécessite un appareil compatible avec Apple Intelligence."),
]},
"de": {
"title": "Support", "intro": "Du hast eine Frage oder ein Problem? Hier findest du Antworten auf die häufigsten Fragen. Wenn deine nicht dabei ist, schreib uns.",
"contact_title": "Kontakt", "contact": "Erstelle ein Issue auf GitHub, beschreibe, was passiert, und füge wenn möglich einen Screenshot hinzu.", "button": "Auf GitHub schreiben",
"faq_title": "Häufige Fragen", "privacy": "Datenschutzerklärung",
"faq": [
("Wo werden meine Daten gespeichert?", "Auf deinem Gerät und, wenn du iCloud nutzt, in deiner privaten iCloud. Niemand sonst hat Zugriff."),
("Verliere ich meinen Schrank, wenn ich die App lösche oder das iPhone wechsle?", "Nein, wenn du iCloud mit derselben Apple-ID nutzt: Die Daten kommen nach der Installation von selbst zurück. Ohne iCloud exportierst du unter Maße › Einstellungen › Sicherung exportieren ein Backup und holst es dort mit „Aus Datei wiederherstellen“ zurück."),
("iPhone und iPad synchronisieren nicht", "Prüfe, ob beide dieselbe Apple-ID nutzen und iCloud aktiviert ist. Die Synchronisierung kann einige Minuten dauern. Unter Maße › Einstellungen siehst du den iCloud-Status."),
("Wie funktionieren QR-Etiketten?", "Öffne bei einem Ort „QR-Etikett“, drucke es aus und klebe es auf die Kiste oder Schublade. Scanne es mit der iPhone-Kamera oder in der App, um zu sehen, was drin ist."),
("Der Hintergrund wird nicht gut entfernt", "Lege das Teil flach auf einen einfarbigen Untergrund bei gutem Licht. Klappt es dann noch nicht, wird das ganze Foto gespeichert."),
("Kann ich Zoll verwenden?", "Ja. Standardmäßig gilt die Einheit deiner Region; ändern kannst du sie unter Maße › Einstellungen › Einheiten."),
("Voraussetzungen", "iPhone oder iPad mit iOS oder iPadOS 17 oder neuer. Die intelligente Suche braucht ein Gerät mit Apple Intelligence."),
]},
"it": {
"title": "Assistenza", "intro": "Hai una domanda o un problema? Ecco le risposte alle domande più frequenti. Se non trovi la tua, scrivici.",
"contact_title": "Contatti", "contact": "Apri una segnalazione su GitHub, racconta cosa succede e, se puoi, aggiungi uno screenshot.", "button": "Scrivi su GitHub",
"faq_title": "Domande frequenti", "privacy": "Informativa sulla privacy",
"faq": [
("Dove sono salvati i miei dati?", "Sul tuo dispositivo e, se usi iCloud, nel tuo iCloud privato. Nessun altro vi ha accesso."),
("Se elimino l’app o cambio iPhone, perdo il mio armadio?", "No, se usi iCloud con lo stesso ID Apple: i dati tornano da soli quando installi l’app. Senza iCloud, esporta un backup in Misure › Impostazioni › Esporta backup e recuperalo dallo stesso punto con «Ripristina da un file»."),
("iPhone e iPad non si sincronizzano", "Controlla che entrambi usino lo stesso ID Apple e che iCloud sia attivo. La sincronizzazione può richiedere qualche minuto. In Misure › Impostazioni vedi lo stato di iCloud."),
("Come funzionano le etichette QR?", "In un posto, apri «Etichetta QR», stampala e attaccala alla scatola o al cassetto. Scansionala con la Fotocamera dell’iPhone o dall’app per vedere cosa contiene."),
("Lo sfondo della foto non viene rimosso bene", "Stendi il capo su uno sfondo uniforme con buona luce. Se ancora non viene rimosso, la foto viene salvata intera."),
("Posso usare i centimetri o i pollici?", "Sì. Di default si usa l’unità della tua regione; puoi cambiarla in Misure › Impostazioni › Unità."),
("Requisiti", "iPhone o iPad con iOS o iPadOS 17 o successivo. La ricerca intelligente richiede un dispositivo compatibile con Apple Intelligence."),
]},
"pt": {
"title": "Suporte", "intro": "Tem uma dúvida ou um problema? Aqui estão as respostas para as perguntas mais comuns. Se não encontrar a sua, fale com a gente.",
"contact_title": "Contato", "contact": "Abra uma issue no GitHub, conte o que está acontecendo e, se puder, adicione uma captura de tela.", "button": "Escrever no GitHub",
"faq_title": "Perguntas frequentes", "privacy": "Política de privacidade",
"faq": [
("Onde meus dados ficam salvos?", "No seu dispositivo e, se você usa o iCloud, no seu iCloud privado. Ninguém mais tem acesso."),
("Se eu apagar o app ou trocar de iPhone, perco meu guarda-roupa?", "Não, se você usa o iCloud com o mesmo ID Apple: os dados voltam sozinhos ao instalar o app. Sem iCloud, exporte um backup em Medidas › Ajustes › Exportar backup e recupere no mesmo lugar com “Restaurar de um arquivo”."),
("Não sincroniza entre o iPhone e o iPad", "Confira se os dois usam o mesmo ID Apple e se o iCloud está ativado. A sincronização pode levar alguns minutos. Em Medidas › Ajustes você vê o estado do iCloud."),
("Como funcionam as etiquetas QR?", "Em um lugar, abra “Etiqueta QR”, imprima e cole na caixa ou gaveta. Escaneie com a Câmera do iPhone ou pelo app para ver o que tem dentro."),
("O fundo da foto não é removido direito", "Estique a peça sobre um fundo liso e com boa luz. Se ainda assim não funcionar, a foto é salva inteira."),
("Posso usar polegadas?", "Sim. Por padrão é usada a unidade da sua região; você pode mudar em Medidas › Ajustes › Unidades."),
("Requisitos", "iPhone ou iPad com iOS ou iPadOS 17 ou posterior. A busca inteligente precisa de um dispositivo compatível com o Apple Intelligence."),
]},
}

STYLE = """
:root{--bg:#F5F5FA;--surface:#FFFFFF;--ink:#16172B;--muted:#5D5F78;--line:#E1E2EE;--accent:#4F5BD5;--on-accent:#FFFFFF;color-scheme:light}
@media (prefers-color-scheme:dark){:root{--bg:#0D0E16;--surface:#171925;--ink:#ECEDF7;--muted:#9C9EB8;--line:#2A2C3E;--accent:#8D95FF;--on-accent:#0D0E16;color-scheme:dark}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:17px/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",Roboto,Helvetica,Arial,sans-serif;padding:0 20px}
main{max-width:680px;margin:0 auto;padding:40px 0 64px}
header{display:flex;align-items:center;gap:14px;margin-bottom:28px}
header img{width:56px;height:56px;border-radius:13px}
header a{color:inherit;text-decoration:none;font-weight:700;font-size:20px}
nav{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:32px}
nav a{padding:6px 14px;border-radius:999px;border:1px solid var(--line);color:var(--muted);text-decoration:none;font-size:15px;background:var(--surface)}
nav a[aria-current="true"]{background:var(--ink);color:var(--bg);border-color:var(--ink)}
h1{font-size:34px;line-height:1.15;margin:0 0 8px;letter-spacing:-.02em;text-wrap:balance}
h2{font-size:20px;margin:28px 0 6px;letter-spacing:-.01em}
p{margin:0 0 12px;max-width:65ch}
.muted{color:var(--muted);font-size:15px}
a{color:var(--accent)}
.card{background:var(--surface);border:1px solid var(--line);border-radius:18px;padding:20px 22px;margin:24px 0}
.card h2{margin-top:0}
.button{display:inline-block;background:var(--accent);color:var(--on-accent);padding:10px 20px;border-radius:999px;text-decoration:none;font-weight:600}
details{border-bottom:1px solid var(--line);padding:14px 0}
summary{font-weight:600;cursor:pointer}
details p{margin:10px 0 0}
footer{margin-top:40px;font-size:15px;color:var(--muted);display:flex;gap:18px;flex-wrap:wrap}
"""

SCRIPT = """
<script>
(function(){
  var codes=%s, sections=document.querySelectorAll('section[data-lang]');
  function pick(){
    var hash=location.hash.replace('#','');
    if(codes.indexOf(hash)>=0) return hash;
    var langs=navigator.languages||[navigator.language||'en'];
    for(var i=0;i<langs.length;i++){var c=langs[i].slice(0,2).toLowerCase(); if(codes.indexOf(c)>=0) return c;}
    return 'en';
  }
  function show(){
    var lang=pick();
    sections.forEach(function(s){s.hidden=s.dataset.lang!==lang});
    document.querySelectorAll('nav a').forEach(function(a){a.setAttribute('aria-current', a.dataset.lang===lang)});
    document.documentElement.lang=lang;
    var section=document.querySelector('section[data-lang="'+lang+'"]');
    if(section) document.title=section.dataset.title+' · Closet Finder';
  }
  window.addEventListener('hashchange', show); show();
})();
</script>
"""


def page(title, sections, base):
    codes = [code for code, _, _ in LANGUAGES]
    nav = "".join(f'<a href="#{code}" data-lang="{code}">{name}</a>' for code, name, _ in LANGUAGES)
    return f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · Closet Finder</title>
<link rel="icon" href="{base}icon.png">
<style>{STYLE}</style>
</head>
<body>
<main>
<header><img src="{base}icon.png" alt=""><a href="{base}">Closet Finder</a></header>
<nav aria-label="Idioma · Language">{nav}</nav>
{sections}
</main>
{SCRIPT % codes}
</body>
</html>
"""


def privacy_section(code):
    text = PRIVACY[code]
    body = "".join(f"<h2>{h}</h2><p>{p.format(issues=ISSUES)}</p>" for h, p in text["sections"])
    return (f'<section data-lang="{code}" data-title="{text["title"]}" lang="{code}">'
            f'<h1>{text["title"]}</h1><p class="muted">{text["updated"]}: {UPDATED[code]}</p>'
            f'<p>{text["intro"]}</p>{body}'
            f'<footer><a href="../support/#{code}">{SUPPORT[code]["title"]}</a></footer></section>')


def support_section(code):
    text = SUPPORT[code]
    faq = "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in text["faq"])
    return (f'<section data-lang="{code}" data-title="{text["title"]}" lang="{code}">'
            f'<h1>{text["title"]}</h1><p>{text["intro"]}</p>'
            f'<div class="card"><h2>{text["contact_title"]}</h2><p>{text["contact"]}</p>'
            f'<a class="button" href="{NEW_ISSUE}">{text["button"]}</a></div>'
            f'<h2>{text["faq_title"]}</h2>{faq}'
            f'<footer><a href="../privacy/#{code}">{text["privacy"]}</a></footer></section>')


def home_section(code):
    support, privacy = SUPPORT[code], PRIVACY[code]
    return (f'<section data-lang="{code}" data-title="Closet Finder" lang="{code}">'
            f'<h1>Closet Finder</h1><p>{privacy["intro"].split(".")[0]}.</p>'
            f'<footer><a href="support/#{code}">{support["title"]}</a>'
            f'<a href="privacy/#{code}">{privacy["title"]}</a></footer></section>')


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as file:
        file.write(content)


codes = [code for code, _, _ in LANGUAGES]
write(os.path.join(DOCS, "privacy", "index.html"),
      page("Política de privacidad", "".join(map(privacy_section, codes)), "../"))
write(os.path.join(DOCS, "support", "index.html"),
      page("Soporte", "".join(map(support_section, codes)), "../"))
write(os.path.join(DOCS, "index.html"), page("Closet Finder", "".join(map(home_section, codes)), ""))
write(os.path.join(DOCS, ".nojekyll"), "")
# Icono de la app, reducido, para la cabecera y la pestaña del navegador.
subprocess.run(["sips", "-Z", "256", os.path.join(ROOT, "ClosetFinder", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png"),
                "--out", os.path.join(DOCS, "icon.png")], check=True, capture_output=True)

for code, _, locale in LANGUAGES:
    write(os.path.join(METADATA, locale, "privacy_url.txt"), f"{BASE_URL}/privacy/#{code}\n")
    write(os.path.join(METADATA, locale, "support_url.txt"), f"{BASE_URL}/support/#{code}\n")
print("docs/ y URL de la ficha actualizadas")
