#!/usr/bin/env python3
"""Genera la ficha del App Store (fastlane/metadata) en los seis idiomas y comprueba los
límites de Apple: nombre y subtítulo 30 caracteres, palabras clave 100, texto promocional 170
y descripción 4000."""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "fastlane", "metadata")

LISTING = {
"es-ES": {
"subtitle": "Encuentra tu ropa al instante",
"keywords": "armario,ropa,organizador,prendas,looks,outfit,maleta,tallas,vestidor,inventario,probador,estilo",
"promotional_text": "Fotografía tu ropa, di dónde la guardas y encuéntrala al momento. Importa fotos en lote, lee etiquetas y descubre lo que vale tu armario.",
"description": """Closet Finder te dice qué ropa tienes en casa y dónde está cada prenda: en qué estancia, en qué mueble y en qué balda, cajón o caja. Se acabó revolver el armario buscando esa chaqueta.

DA DE ALTA TU ROPA EN SEGUNDOS
• Haz una foto: la app recorta el fondo, detecta el color y sugiere qué prenda es.
• Importa hasta 50 fotos de una vez y revisa solo las dudosas.
• Lee la etiqueta interior para rellenar la talla, la composición y el lavado.
• Modo ráfaga para fotografiar un cajón entero seguido.

TU CASA, ORDENADA
• Estancias, muebles y compartimentos, con plantillas de armario, cómoda y zapatero.
• Cada prenda muestra el esquema del mueble con su balda o cajón marcado.
• Etiquetas QR para cajas y cajones: escanéalas y verás qué hay dentro.
• Mueve varias prendas a la vez cuando cambias la ropa de sitio.

LOOKS, SEMANA Y MALETAS
• Probador: desliza una prenda por cada parte del cuerpo y guarda tus looks.
• Planifica qué ponerte cada día de la semana.
• Maletas: añade looks y prendas sueltas y obtén la lista de qué llevar, agrupada por dónde está cada cosa. La app sugiere capas y looks según la época del viaje.
• Comparte un look como imagen.

ENCUENTRA CUALQUIER PRENDA
• Busca por nombre, color, tipo, temporada o estado: prestada, lavando o para donar.
• Con Apple Intelligence, escribe frases como «algo de abrigo para la nieve».
• Spotlight, Siri y un widget configurable para la pantalla de inicio.

TALLAS Y MEDIDAS
• Guarda las medidas de cada persona de casa y consulta sus tallas EU, US y UK.
• «¿Me queda bien?» compara las medidas de la prenda con las tuyas.
• En centímetros o en pulgadas.

CONOCE TU ARMARIO
• Estadísticas por categoría y estancia, prendas olvidadas, prestadas y para donar.
• Valor del armario, gasto por año y coste por puesta de cada prenda.
• Tu año en ropa: tu prenda estrella, tu look más repetido y tus colores.
• Huecos en el armario: qué parte les falta a tus looks.

TUS DATOS SON TUYOS
• Todo se guarda en el iPhone y en tu iCloud privado, y se sincroniza con tu iPad.
• Copia de seguridad en un archivo cuando quieras.
• Sin cuentas, sin anuncios y sin recopilar datos.

Para iPhone y iPad, en español, inglés, francés, alemán, italiano y portugués, con modo claro y oscuro.""",
},
"en-US": {
"subtitle": "Know where every item is",
"keywords": "wardrobe,clothes,organizer,outfit,packing,sizes,inventory,style,fitting room,looks,planner,tracker",
"promotional_text": "Photograph your clothes, say where you keep them and find them in seconds. Import photos in bulk, read care labels and see what your closet is worth.",
"description": """Closet Finder tells you what clothes you have at home and exactly where each item is: which room, which piece of furniture and which shelf, drawer or box. No more digging through the closet for that jacket.

ADD YOUR CLOTHES IN SECONDS
• Take a photo: the app removes the background, detects the color and suggests what it is.
• Import up to 50 photos at once and only review the unclear ones.
• Read the inside label to fill in the size, fabric and care instructions.
• Burst mode to photograph a whole drawer in one go.

YOUR HOME, ORGANIZED
• Rooms, furniture and compartments, with templates for wardrobes, dressers and shoe racks.
• Each item shows a diagram of its furniture with the shelf or drawer highlighted.
• QR labels for boxes and drawers: scan them to see what’s inside.
• Move several items at once when you rearrange your clothes.

LOOKS, WEEK AND SUITCASES
• Fitting room: swipe an item for each part of the body and save your looks.
• Plan what to wear every day of the week.
• Suitcases: add looks and extra items and get a packing list grouped by where everything is. The app suggests layers and looks for the time of year of your trip.
• Share a look as an image.

FIND ANY ITEM
• Search by name, color, type, season or status: lent out, in the wash or to donate.
• With Apple Intelligence, type phrases like “something warm for the snow”.
• Spotlight, Siri and a configurable Home Screen widget.

SIZES AND MEASUREMENTS
• Save the measurements of everyone at home and see their EU, US and UK sizes.
• “Does it fit?” compares the item’s measurements with yours.
• In inches or centimeters.

KNOW YOUR CLOSET
• Statistics by category and room, forgotten items, lent out and to donate.
• Closet value, spending per year and cost per wear for each item.
• Your year in clothes: your star item, your most repeated look and your colors.
• Gaps in your closet: what your looks are missing.

YOUR DATA IS YOURS
• Everything is stored on your iPhone and in your private iCloud, synced with your iPad.
• Back up to a file whenever you want.
• No accounts, no ads and no data collection.

For iPhone and iPad, in English, Spanish, French, German, Italian and Portuguese, with light and dark mode.""",
},
"fr-FR": {
"subtitle": "Retrouvez vos vêtements",
"keywords": "dressing,vêtements,garde-robe,armoire,tenue,look,valise,tailles,rangement,inventaire,style",
"promotional_text": "Photographiez vos vêtements, indiquez où ils sont rangés et retrouvez-les vite. Importez des photos en lot, lisez les étiquettes et voyez la valeur de votre dressing.",
"description": """Closet Finder vous dit quels vêtements vous avez chez vous et où se trouve chacun : dans quelle pièce, quel meuble et sur quelle étagère, dans quel tiroir ou quelle boîte. Fini de tout retourner pour trouver cette veste.

AJOUTEZ VOS VÊTEMENTS EN QUELQUES SECONDES
• Prenez une photo : l’app retire le fond, détecte la couleur et suggère de quel vêtement il s’agit.
• Importez jusqu’à 50 photos d’un coup et ne vérifiez que les cas douteux.
• Lisez l’étiquette intérieure pour remplir la taille, la composition et l’entretien.
• Mode rafale pour photographier tout un tiroir à la suite.

VOTRE MAISON, BIEN RANGÉE
• Pièces, meubles et compartiments, avec des modèles d’armoire, de commode et de meuble à chaussures.
• Chaque vêtement affiche le schéma de son meuble avec l’étagère ou le tiroir mis en évidence.
• Étiquettes QR pour boîtes et tiroirs : scannez-les pour voir ce qu’ils contiennent.
• Déplacez plusieurs vêtements à la fois quand vous réorganisez.

LOOKS, SEMAINE ET VALISES
• Cabine d’essayage : faites défiler une pièce pour chaque partie du corps et enregistrez vos looks.
• Planifiez quoi porter chaque jour de la semaine.
• Valises : ajoutez des looks et des pièces et obtenez la liste de ce qu’il faut emporter, regroupée par emplacement. L’app suggère couches et looks selon la saison du voyage.
• Partagez un look en image.

RETROUVEZ N’IMPORTE QUEL VÊTEMENT
• Cherchez par nom, couleur, type, saison ou état : prêté, au lavage ou à donner.
• Avec Apple Intelligence, écrivez des phrases comme « quelque chose de chaud pour la neige ».
• Spotlight, Siri et un widget configurable pour l’écran d’accueil.

TAILLES ET MESURES
• Enregistrez les mesures de chaque personne de la maison et voyez ses tailles EU, US et UK.
• « Est-ce que ça me va ? » compare les mesures du vêtement avec les vôtres.
• En centimètres ou en pouces.

CONNAISSEZ VOTRE DRESSING
• Statistiques par catégorie et par pièce, vêtements oubliés, prêtés et à donner.
• Valeur du dressing, dépenses par an et coût par utilisation de chaque vêtement.
• Votre année en vêtements : votre pièce star, votre look le plus porté et vos couleurs.
• Ce qui manque à votre dressing : la pièce qui manque à vos looks.

VOS DONNÉES VOUS APPARTIENNENT
• Tout est enregistré sur l’iPhone et dans votre iCloud privé, synchronisé avec votre iPad.
• Sauvegarde dans un fichier quand vous le souhaitez.
• Sans compte, sans publicité et sans collecte de données.

Pour iPhone et iPad, en français, anglais, espagnol, allemand, italien et portugais, en mode clair et sombre.""",
},
"de-DE": {
"subtitle": "Finde jedes Kleidungsstück",
"keywords": "Kleiderschrank,Kleidung,Outfit,Garderobe,Koffer,Größen,Ordnung,Inventar,Stil,Looks,Planer",
"promotional_text": "Fotografiere deine Kleidung, gib an, wo sie liegt, und finde sie sofort. Importiere Fotos im Stapel, lies Etiketten und sieh, was dein Schrank wert ist.",
"description": """Closet Finder sagt dir, welche Kleidung du zu Hause hast und wo jedes Teil ist: in welchem Raum, in welchem Möbel und in welchem Fach, welcher Schublade oder Kiste. Nie wieder den ganzen Schrank nach dieser einen Jacke durchwühlen.

KLEIDUNG IN SEKUNDEN ERFASSEN
• Mach ein Foto: Die App entfernt den Hintergrund, erkennt die Farbe und schlägt vor, was es ist.
• Importiere bis zu 50 Fotos auf einmal und prüfe nur die unklaren.
• Lies das Innenetikett, um Größe, Material und Pflege auszufüllen.
• Serienmodus, um eine ganze Schublade am Stück zu fotografieren.

DEIN ZUHAUSE, AUFGERÄUMT
• Räume, Möbel und Fächer, mit Vorlagen für Kleiderschrank, Kommode und Schuhschrank.
• Jedes Teil zeigt eine Skizze seines Möbels mit markiertem Fach oder markierter Schublade.
• QR-Etiketten für Kisten und Schubladen: Scanne sie und sieh, was drin ist.
• Verschiebe mehrere Teile auf einmal, wenn du umräumst.

LOOKS, WOCHE UND KOFFER
• Umkleide: Wische für jeden Körperbereich durch die Teile und speichere deine Looks.
• Plane, was du an jedem Tag der Woche trägst.
• Koffer: Füge Looks und einzelne Teile hinzu und erhalte eine Packliste, sortiert nach Aufbewahrungsort. Die App schlägt passend zur Reisezeit Lagen und Looks vor.
• Teile einen Look als Bild.

JEDES TEIL FINDEN
• Suche nach Name, Farbe, Art, Saison oder Status: verliehen, in der Wäsche oder zum Spenden.
• Mit Apple Intelligence kannst du Sätze wie „etwas Warmes für den Schnee“ eingeben.
• Spotlight, Siri und ein anpassbares Widget für den Home-Bildschirm.

GRÖSSEN UND MASSE
• Speichere die Maße aller im Haushalt und sieh ihre Größen in EU, US und UK.
• „Passt es mir?“ vergleicht die Maße des Teils mit deinen.
• In Zentimetern oder Zoll.

LERNE DEINEN SCHRANK KENNEN
• Statistiken nach Kategorie und Raum, vergessene, verliehene und zu spendende Teile.
• Wert des Schranks, Ausgaben pro Jahr und Kosten pro Tragen jedes Teils.
• Dein Jahr in Kleidung: dein Lieblingsteil, dein meistgetragener Look und deine Farben.
• Lücken im Schrank: welches Teil deinen Looks fehlt.

DEINE DATEN GEHÖREN DIR
• Alles wird auf dem iPhone und in deiner privaten iCloud gespeichert und mit dem iPad synchronisiert.
• Backup als Datei, wann immer du willst.
• Kein Konto, keine Werbung und keine Datenerfassung.

Für iPhone und iPad, auf Deutsch, Englisch, Spanisch, Französisch, Italienisch und Portugiesisch, mit hellem und dunklem Modus.""",
},
"it": {
"subtitle": "Ritrova ogni capo in casa",
"keywords": "armadio,vestiti,guardaroba,outfit,look,valigia,taglie,organizzare,inventario,stile,camerino",
"promotional_text": "Fotografa i tuoi vestiti, indica dove li tieni e ritrovali in un attimo. Importa foto in blocco, leggi le etichette e scopri quanto vale il tuo armadio.",
"description": """Closet Finder ti dice quali vestiti hai in casa e dove si trova ogni capo: in quale stanza, in quale mobile e su quale ripiano, cassetto o scatola. Basta mettere sottosopra l’armadio per trovare quella giacca.

AGGIUNGI I TUOI VESTITI IN POCHI SECONDI
• Scatta una foto: l’app rimuove lo sfondo, riconosce il colore e suggerisce che capo è.
• Importa fino a 50 foto alla volta e controlla solo quelle dubbie.
• Leggi l’etichetta interna per compilare taglia, composizione e lavaggio.
• Modalità a raffica per fotografare un intero cassetto di seguito.

LA TUA CASA, IN ORDINE
• Stanze, mobili e scomparti, con modelli di armadio, cassettiera e scarpiera.
• Ogni capo mostra lo schema del suo mobile con il ripiano o il cassetto evidenziato.
• Etichette QR per scatole e cassetti: scansionale e vedrai cosa c’è dentro.
• Sposta più capi insieme quando riorganizzi.

LOOK, SETTIMANA E VALIGIE
• Camerino: scorri un capo per ogni parte del corpo e salva i tuoi look.
• Pianifica cosa indossare ogni giorno della settimana.
• Valigie: aggiungi look e capi singoli e ottieni la lista di cosa portare, raggruppata per posizione. L’app suggerisce strati e look in base al periodo del viaggio.
• Condividi un look come immagine.

TROVA QUALSIASI CAPO
• Cerca per nome, colore, tipo, stagione o stato: prestato, in lavatrice o da donare.
• Con Apple Intelligence, scrivi frasi come «qualcosa di caldo per la neve».
• Spotlight, Siri e un widget configurabile per la schermata Home.

TAGLIE E MISURE
• Salva le misure di ogni persona di casa e consulta le sue taglie EU, US e UK.
• «Mi sta bene?» confronta le misure del capo con le tue.
• In centimetri o in pollici.

CONOSCI IL TUO ARMADIO
• Statistiche per categoria e stanza, capi dimenticati, prestati e da donare.
• Valore dell’armadio, spesa annuale e costo per utilizzo di ogni capo.
• Il tuo anno in vestiti: il capo preferito, il look più ripetuto e i tuoi colori.
• Mancanze nell’armadio: quale parte manca ai tuoi look.

I TUOI DATI SONO TUOI
• Tutto viene salvato sull’iPhone e nel tuo iCloud privato, sincronizzato con l’iPad.
• Backup su file quando vuoi.
• Nessun account, nessuna pubblicità e nessuna raccolta di dati.

Per iPhone e iPad, in italiano, inglese, spagnolo, francese, tedesco e portoghese, con modalità chiara e scura.""",
},
"pt-BR": {
"subtitle": "Ache suas roupas na hora",
"keywords": "guarda-roupa,roupas,closet,organizador,looks,mala,tamanhos,inventário,estilo,provador,outfit",
"promotional_text": "Fotografe suas roupas, diga onde as guarda e encontre tudo na hora. Importe fotos em lote, leia etiquetas e descubra quanto vale seu guarda-roupa.",
"description": """O Closet Finder mostra quais roupas você tem em casa e onde está cada peça: em qual cômodo, em qual móvel e em qual prateleira, gaveta ou caixa. Chega de revirar o guarda-roupa atrás daquela jaqueta.

CADASTRE SUAS ROUPAS EM SEGUNDOS
• Tire uma foto: o app remove o fundo, detecta a cor e sugere qual peça é.
• Importe até 50 fotos de uma vez e revise só as duvidosas.
• Leia a etiqueta interna para preencher tamanho, composição e lavagem.
• Modo sequência para fotografar uma gaveta inteira de uma vez.

SUA CASA, ORGANIZADA
• Cômodos, móveis e compartimentos, com modelos de guarda-roupa, cômoda e sapateira.
• Cada peça mostra o desenho do móvel com a prateleira ou gaveta destacada.
• Etiquetas QR para caixas e gavetas: escaneie e veja o que tem dentro.
• Mova várias peças de uma vez quando reorganizar.

LOOKS, SEMANA E MALAS
• Provador: deslize uma peça para cada parte do corpo e salve seus looks.
• Planeje o que vestir em cada dia da semana.
• Malas: adicione looks e peças avulsas e receba a lista do que levar, agrupada por onde está cada coisa. O app sugere camadas e looks de acordo com a época da viagem.
• Compartilhe um look como imagem.

ENCONTRE QUALQUER PEÇA
• Busque por nome, cor, tipo, estação ou situação: emprestada, lavando ou para doar.
• Com o Apple Intelligence, escreva frases como “algo quente para a neve”.
• Spotlight, Siri e um widget configurável para a Tela de Início.

TAMANHOS E MEDIDAS
• Guarde as medidas de cada pessoa da casa e veja seus tamanhos EU, US e UK.
• “Fica bem em mim?” compara as medidas da peça com as suas.
• Em centímetros ou polegadas.

CONHEÇA SEU GUARDA-ROUPA
• Estatísticas por categoria e cômodo, peças esquecidas, emprestadas e para doar.
• Valor do guarda-roupa, gasto por ano e custo por uso de cada peça.
• Seu ano em roupas: sua peça estrela, o look mais repetido e suas cores.
• Lacunas no guarda-roupa: o que falta nos seus looks.

SEUS DADOS SÃO SEUS
• Tudo fica salvo no iPhone e no seu iCloud privado, sincronizado com seu iPad.
• Backup em arquivo quando quiser.
• Sem contas, sem anúncios e sem coleta de dados.

Para iPhone e iPad, em português, inglês, espanhol, francês, alemão e italiano, com modo claro e escuro.""",
},
}

LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotional_text": 170, "description": 4000}

errors = []
for locale, fields in LISTING.items():
    fields = {"name": "Closet Finder", **fields}
    folder = os.path.join(OUT, locale)
    os.makedirs(folder, exist_ok=True)
    for field, text in fields.items():
        if len(text) > LIMITS[field]:
            errors.append(f"{locale}/{field}: {len(text)} > {LIMITS[field]}")
        if field == "keywords" and any(word.strip() != word for word in text.split(",")):
            errors.append(f"{locale}/keywords: espacios alrededor de las comas")
        with open(os.path.join(folder, f"{field}.txt"), "w") as file:
            file.write(text + "\n")
    print(locale, {f: len(t) for f, t in fields.items()})

# Datos comunes a todos los idiomas.
for name, value in {"copyright.txt": "2026 Sergio González Díaz", "primary_category.txt": "LIFESTYLE",
                    "secondary_category.txt": "PRODUCTIVITY"}.items():
    with open(os.path.join(OUT, name), "w") as file:
        file.write(value + "\n")

if errors:
    raise SystemExit("\n".join(errors))
