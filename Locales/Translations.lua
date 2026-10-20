local _, addon = ...
-- Interface strings; title dictionaries are loaded separately.
addon.locales.deDE = { ["SEARCH_OBJECTIVE_MATCH"] = "Questziel: %s", ["SEARCH_NPC_MATCH"] = "NPC: %s", ["SEARCH_PLACE_MATCH"] = "Ort: %s", ["OBJECTIVE_ITEM_SOURCES"] = "Fundorte für Questgegenstände", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "Gemeldete Gegenstandsquellen; die Verfügbarkeit ist nicht bestätigt.", ["LANGUAGE_AUTO_SHORT"] = "Auto", ["QUEST_LEVEL"] = "Queststufe: %.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "Abgabe: %s", ["DIALOGUE_PROGRESS_TEXT"] = "Aktueller Questdialog", ["DIALOGUE_TURNIN_TEXT"] = "Aktueller Abgabedialog", ["GAME_WAYPOINT"] = "Wegpunkt des Spiels", ["GAME_WAYPOINT_NOTICE"] = "Der Wegpunkt kann eine Route, einen Eingang oder einen Abgabeort markieren.", ["GAME_WAYPOINT_FOLLOW"] = "Spielwegpunkt folgen", ["QUEST_LOG_PAYMENT"] = "Zahlung im Questlog: %s", ["PREPARATION_EMPTY"] = "Es werden keine Vorbereitungsschritte angezeigt. Wechsle zu %s, um die aufgeführten Quests anzusehen.", ["QUEST_PAYMENT"] = "Angegebene Zahlung: %s", ["MONEY_COPPER"] = "%.0f Kupfer", ["QUEST_PAYMENT_NOTICE"] = "Diese Kosten bestätigen nicht, dass die Quest verfügbar ist.", ["SEARCH_QUEST_MATCH"] = "Quest: %s", ["STORY_SOURCE_QUESTS"] = "In der Geschichte aufgeführte Quests: %d", ["OBJECTIVE_OBJECTS"] = "Weitere aufgeführte Ziele", ["OBJECTIVE_OBJECTS_NOTICE"] = "Die aufgeführten Aufgaben sind Questziele, keine bestätigten Annahmebedingungen oder Angaben zum aktuellen Fortschritt.", ["OPEN_QUEST_LOG"] = "Im Questlog öffnen", ["QUEST_TEXT"] = "Questtext", ["ITEM_DROP_LOCATIONS"] = "Bekannte Fundorte — Verfügbarkeit unbestätigt", ["ITEM_ACQUISITION"] = "Den Queststartgegenstand finden", ["ITEM_ACQUISITION_UNKNOWN"] = "Die Herkunft des Gegenstands ist noch nicht bestätigt.", ["PROVIDED_ITEMS"] = "Für die Quest bereitgestellte Gegenstände", ["PROVIDED_ITEMS_NOTICE"] = "Bereitgestellte Gegenstände können während der Quest verwendet oder verbraucht werden. Dein aktueller Besitz wird separat angezeigt.", ["OBJECTIVE_KILLS"] = "Aufgeführte Tötungsziele", ["OBJECTIVE_KILLS_NOTICE"] = "Die aufgeführten Ziele sind Questziele, keine bestätigten Annahmebedingungen oder Angaben zum aktuellen Fortschritt.", ["GIVER_REFERENCE_PORTRAIT"] = "Questgeber: %s", ["QUEST_FACTIONS"] = "Fraktionen: %s", ["PREPARATION_FOR"] = "Vorbereitung für", ["PREPARATION_FOR_NOTICE"] = "Ziele des aktuellen Vorbereitungsplans; andere Wege können möglich sein.", ["LANGUAGE_AUTO"] = "Automatisch (Spielsprache)", ["GUIDE_DISTANCE"] = "%.0f yd", ["BRANCH_INSPECT"] = "Quest ansehen", ["OVERVIEW_PICK"] = "Wähle eine aufgeführte Quest aus, um Details und Vorbereitungsschritte zu sehen.", ["OVERVIEW_REVIEWED"] = "Questliste geprüft; einzelne Voraussetzungen können noch unbestätigt sein.", ["FACTION_Alliance"] = "Allianz", ["FACTION_Horde"] = "Horde", ["FACTION_Neutral"] = "Neutral", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — Menge nicht bestätigt", ["MINIMAP_OPEN"] = "Linksklick: Dungeon Pro öffnen oder schließen.", ["MINIMAP_DRAG"] = "Ziehen, um das Symbol an der Minikarte zu verschieben.", ["OBJECTIVE_ITEMS"] = "Aufgeführte Gegenstandsziele", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "Die aufgeführten Gegenstände sind Questziele, keine bestätigten Annahmebedingungen oder Angaben zum aktuellen Fortschritt.",  ["QUEST_MIN_LEVEL"] = "Mindeststufe: %.0f", ["QUEST_CLASSES"] = "Klassen: %s", ["QUEST_RACES"] = "Völker: %s", ["RACE_ID"] = "Volk #%.0f",  ["QUEST_LOG_CAPACITY"] = "Questlog: %.0f/%.0f", ["ITEM_CARRIED"] = "Mitgeführt: %.0f", ["DUNGEON_WING_lower"] = "%s — Unterer Bereich", ["DUNGEON_WING_upper"] = "%s — Oberer Bereich", ["REWARD_PREVIEW"] = "Vorschau der Questbelohnungen", ["UNKNOWN_REQUIREMENTS"] = "Nicht im Questlog — Voraussetzungen ungeprüft", ["CONTAINER_SOURCE"] = "Bekannter Gegenstandsbehälter — Verfügbarkeit unbestätigt", ["REPORTED_POSITIONS"] = "Gemeldete Positionen: %s (%d)", ["REPORTED_NOTICE"] = "Diese Punkte können Bewegungen oder Questphasen widerspiegeln. Sie bestätigen nicht den aktuellen Standort des NSC oder Objekts.", ["REPORTED_VISIT"] = "Diese gemeldete Position besuchen", ["COMPLETED_BEFORE"] = "Bereits früher abgeschlossen", ["DETAIL_BACK"] = "Zurück", ["REQUIREMENT_GROUPS"] = "Bekannte Voraussetzungengruppen", ["REQUIREMENT_NOTICE"] = "Jede aufgeführte Gruppe ist erforderlich; eine Quest pro Gruppe genügt. Weitere Bedingungen können unbekannt sein.", ["REQUIREMENT_GROUP"] = "Voraussetzung %d", ["REQUIREMENT_ACTIVE"] = "Eine Quest annehmen oder abschließen.", ["REQUIREMENT_COMPLETE"] = "Eine Quest abschließen.", ["CATALOG_LEVELS"] = "Stufen %d–%d", ["CATALOG_QUESTS"] = "Aufgeführte Quests: %d", ["OBJECTIVE_DIALOGUE"] = "Ziel im geöffneten Questdialog", ["OBJECTIVE_PROGRESS"] = "Vom Spiel gemeldete Ziele", ["REWARD_DIALOGUE"] = "Belohnungen im geöffneten Questdialog", ["REWARD_HIDDEN"] = "Der Client zeigt für diese Quest keine Belohnungen an.", ["REWARD_XP"] = "Erfahrung: %d",  ["OFFERED_NOW"] = "Wird im aktuellen NPC-Dialog angeboten.", ["ITEM_CLASSES"] = "Gegenstandsklassen: %s", ["ITEM_MIN_LEVEL"] = "Der Gegenstand erfordert Stufe %d.", ["ITEM_REQUIREMENTS_NOTICE"] = "Nur Gegenstandsanforderungen. Die Questverfügbarkeit wird separat geprüft.", ["POSSIBLE_TURNINS"] = "Mögliche Abgabestellen — Verfügbarkeit unbestätigt", ["STORY_GROUP"] = "Handlungsgruppe %d", ["STORY_GROUP_NOTICE"] = "Die Quelle zeigt diese Quests zusammen. Das bestätigt weder Voraussetzungen noch, welche Quests dein Charakter annehmen kann.", ["START_ALTERNATIVES"] = "Mögliche Startpunkte — Verfügbarkeit unbestätigt", ["ITEM_STARTER"] = "Queststartgegenstand: %s", ["ITEM_DROP_SOURCE"] = "Wird von %s in %s fallen gelassen.", ["QUEST_PORTRAIT"] = "Questporträt", ["REPEATABLE"] = "Wiederholbare Quest", ["MATERIAL_QUESTS"] = "Quests für benötigte Materialien", ["MATERIAL_ITEM"] = "Gegenstand #%d", ["MATERIAL_NOTICE"] = "Diese Quests liefern Materialien zum Abschluss, sind aber keine bestätigten Annahmevoraussetzungen. Ein Abschluss bestätigt nicht, dass du den Gegenstand noch besitzt.", ["SEARCH_HELP"] = "Suche nach Dungeons, aufgeführten Quests, erfassten NPCs und Orten oder gib eine Quest-ID ein. Groß-/Kleinschreibung wird ignoriert; Akzente und Schreibweise zählen.", ["NO_DUNGEONS"] = "Keine Dungeons entsprechen der Suche und den gewählten Filtern.", ["REWARD_ITEMS"] = "Gegenstandsbelohnungen", ["REWARD_CHOICES"] = "Einen Gegenstand wählen", ["REWARD_ITEM"] = "%s ×%d", ["REWARD_NO_ITEMS"] = "Keine Gegenstandsbelohnungen.", ["REWARD_UNAVAILABLE"] = "Belohnungsdaten für diese Quest sind nicht verfügbar.", ["REWARD_MONEY"] = "Geld", ["REWARD_MONEY_UNKNOWN"] = "Die Geldbelohnung konnte nicht angezeigt werden.", ["BRANCH_GROUP"] = "Voraussetzung %d: eine wählen", ["BRANCH_AUTO"] = "Automatisch", ["BRANCH_SELECTED"] = "%s (ausgewählt)", ["VISIT_GIVER"] = "Questgeber besuchen", ["GIVER_MAP"] = "Questgeber auf Karte", ["LOCATION_ONLY"] = "Nur der Standort; die Questverfügbarkeit ist nicht bestätigt.", ["NO_CHARACTER_QUESTS"] = "Keine bekannten Quests für diesen Charakter. Wechsle zu %s, um die übrigen anzusehen.", ["MY_CHARACTER"] = "Mein Charakter", ["ALL_CHARACTERS"] = "Alle Charaktere", ["PREP_unavailable"] = "Nicht für diesen Charakter", ["REASON_requirements"] = "Erforderliche Questschritte sind noch offen.", ["REASON_requirementsUnknown"] = "Die Questvoraussetzungen sind noch nicht vollständig geprüft.", ["REASON_character"] = "Questverlauf oder Charakterbeschränkungen konnten nicht geprüft werden.", ["REASON_level"] = "Benötigt Level %d.", ["REASON_level_current"] = "Benötigt Level %d; aktuelles Level: %d.", ["REASON_levelUnknown"] = "Dein Level konnte nicht geprüft werden.", ["REASON_missing"] = "Angaben zu dieser Quest fehlen im Katalog.", ["REASON_cycle"] = "Die Questabhängigkeiten enthalten einen Kreis; die Verfügbarkeit ist unklar.", ["REASON_faction"] = "Deine Fraktion erfüllt die Questvoraussetzungen nicht.", ["REASON_class"] = "Deine Klasse erfüllt die Questvoraussetzungen nicht.", ["REASON_race"] = "Dein Volk erfüllt die Questvoraussetzungen nicht.", ["PREP_outside"] = "Vor dem Betreten annehmen", ["PREP_inside"] = "Im Dungeon annehmen", ["PREP_level"] = "Levelvoraussetzungen", ["PREP_progress"] = "Abschließen oder abgeben", ["PREP_uncertain"] = "Voraussetzungen noch unbekannt", ["ACTIVE"] = "Im Questlog", ["ALL"] = "Alle Level", ["AVAILABLE"] = "Verfügbar", ["CHAIN"] = "Questreihe", ["CLEAR"] = "Wegweiser entfernen", ["COMPLETED"] = "Abgeschlossen", ["COPY"] = "Link markieren und Strg+C drücken.", ["DEVELOPMENT"] = "Entwicklungsversion — Dungeonabdeckung unvollständig", ["EMPTY"] = "Für diesen Dungeon fehlen noch Questdaten.", ["ENDING"] = "Abgabe", ["GUIDE"] = "Richtung anzeigen", ["LOCKED"] = "Vorbereitung nötig", ["MAP"] = "Auf Karte zeigen", ["NEXT"] = "Nächster Schritt", ["NOT_PREPARED"] = "Vorbereitung ausstehend", ["NO_POSITION"] = "Position nicht verfügbar oder Ziel auf anderem Kontinent", ["NO_TEXT"] = "Der ursprüngliche Questtext ist nicht verfügbar. Öffne das Questangebot, um ihn zu speichern.", ["ONLY_EN_RU"] = "Sprache", ["PARTIAL"] = "Vollständigkeit wird noch geprüft", ["PICK"] = "Dungeon und dann Quest auswählen.", ["PREPARED"] = "Bekannte Quests vorbereitet", ["QUESTS"] = "Dungeonquests", ["RANGE"] = "Mein Level", ["READY"] = "Bereit zur Abgabe", ["SEARCH"] = "Dungeon, Quest, NPC", ["SOURCE"] = "Wowhead-Link", ["START"] = "Beginn", ["STORY"] = "Handlungsfolge (Voraussetzungen werden geprüft)", ["SUBTITLE"] = "Vor dem Betreten vorbereiten", ["SUMMARY"] = "Angenommen: %d   Abgeschlossen: %d   Vorbereitung: %d   Unbekannt: %d", ["TITLE"] = "Dungeon Pro", ["UNAVAILABLE"] = "Nicht für diesen Charakter", ["UNKNOWN"] = "Nicht genug Informationen", ["UNKNOWN_PLACE"] = "Ort noch unbekannt", ["UNSUPPORTED"] = "Diese Version unterstützt nur WoW Forever.", ["complete"] = "Quest abschließen", ["inside"] = "Im Dungeon annehmen", ["level"] = "Level erreichen", ["pickup"] = "Annehmen", ["turnin"] = "Abgeben" }
addon.locales.frFR = { ["SEARCH_OBJECTIVE_MATCH"] = "Objectif de quête : %s", ["SEARCH_NPC_MATCH"] = "PNJ : %s", ["SEARCH_PLACE_MATCH"] = "Lieu : %s", ["OBJECTIVE_ITEM_SOURCES"] = "Où trouver les objets de quête", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "Sources signalées ; la disponibilité des objets reste à confirmer.", ["LANGUAGE_AUTO_SHORT"] = "Auto", ["QUEST_LEVEL"] = "Niveau de quête : %.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "Remise : %s", ["DIALOGUE_PROGRESS_TEXT"] = "Dialogue de quête actuel", ["DIALOGUE_TURNIN_TEXT"] = "Dialogue de remise actuel", ["GAME_WAYPOINT"] = "Point de passage du jeu", ["GAME_WAYPOINT_NOTICE"] = "Ce point peut indiquer un itinéraire, une entrée ou un lieu de remise de quête.", ["GAME_WAYPOINT_FOLLOW"] = "Suivre le point du jeu", ["QUEST_LOG_PAYMENT"] = "Paiement dans le journal de quêtes : %s", ["PREPARATION_EMPTY"] = "Aucune étape de préparation affichée. Passez à %s pour voir la liste des quêtes.", ["QUEST_PAYMENT"] = "Paiement indiqué : %s", ["MONEY_COPPER"] = "%.0f pièces de cuivre", ["QUEST_PAYMENT_NOTICE"] = "Ce coût ne confirme pas que la quête est disponible.", ["SEARCH_QUEST_MATCH"] = "Quête : %s", ["STORY_SOURCE_QUESTS"] = "Quêtes de la trame : %d", ["OBJECTIVE_OBJECTS"] = "Autres objectifs indiqués", ["OBJECTIVE_OBJECTS_NOTICE"] = "Ces tâches sont des objectifs de quête, pas des conditions d’acceptation confirmées ni une indication de la progression actuelle.", ["OPEN_QUEST_LOG"] = "Ouvrir dans le journal", ["QUEST_TEXT"] = "Texte de la quête", ["ITEM_DROP_LOCATIONS"] = "Lieux de butin connus — disponibilité non confirmée", ["ITEM_ACQUISITION"] = "Obtenir l’objet qui lance la quête", ["ITEM_ACQUISITION_UNKNOWN"] = "La source de cet objet n’a pas encore été vérifiée.", ["PROVIDED_ITEMS"] = "Objets fournis pour la quête", ["PROVIDED_ITEMS_NOTICE"] = "Les objets fournis peuvent être utilisés ou consommés pendant la quête. Les objets actuellement en votre possession sont indiqués séparément.", ["OBJECTIVE_KILLS"] = "Objectifs de mise à mort indiqués", ["OBJECTIVE_KILLS_NOTICE"] = "Les cibles indiquées sont des objectifs de quête, pas des conditions confirmées pour l’accepter ni la progression actuelle.", ["GIVER_REFERENCE_PORTRAIT"] = "Donneur de quête : %s", ["QUEST_FACTIONS"] = "Factions : %s", ["PREPARATION_FOR"] = "Préparation pour", ["PREPARATION_FOR_NOTICE"] = "Objectifs du plan de préparation actuel ; d’autres voies peuvent être possibles.", ["LANGUAGE_AUTO"] = "Automatique (langue du jeu)", ["GUIDE_DISTANCE"] = "%.0f yd", ["BRANCH_INSPECT"] = "Voir la quête", ["OVERVIEW_PICK"] = "Sélectionnez une quête de la liste pour voir ses détails et les étapes de préparation.", ["OVERVIEW_REVIEWED"] = "Liste de quêtes vérifiée ; certaines conditions peuvent encore être non confirmées.", ["FACTION_Alliance"] = "Alliance", ["FACTION_Horde"] = "Horde", ["FACTION_Neutral"] = "Neutre", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — quantité non vérifiée", ["MINIMAP_OPEN"] = "Clic gauche : ouvrir ou fermer Dungeon Pro.", ["MINIMAP_DRAG"] = "Faites glisser l’icône autour de la minicarte.", ["OBJECTIVE_ITEMS"] = "Objectifs d’objets indiqués", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "Les objets indiqués sont des objectifs de quête, pas des conditions d’acceptation confirmées ni le suivi actuel de la progression.",  ["QUEST_MIN_LEVEL"] = "Niveau minimum : %.0f", ["QUEST_CLASSES"] = "Classes : %s", ["QUEST_RACES"] = "Races : %s", ["RACE_ID"] = "Race n°%.0f",  ["QUEST_LOG_CAPACITY"] = "Journal de quêtes : %.0f/%.0f", ["ITEM_CARRIED"] = "Sur vous : %.0f", ["DUNGEON_WING_lower"] = "%s — Aile inférieure", ["DUNGEON_WING_upper"] = "%s — Aile supérieure", ["REWARD_PREVIEW"] = "Aperçu des récompenses de quête", ["UNKNOWN_REQUIREMENTS"] = "Absente du journal — prérequis non vérifiés", ["CONTAINER_SOURCE"] = "Conteneur connu de l’objet — disponibilité non confirmée", ["REPORTED_POSITIONS"] = "Positions signalées : %s (%d)", ["REPORTED_NOTICE"] = "Ces points peuvent correspondre à des déplacements ou à des phases de quête. Ils ne confirment pas la position actuelle du PNJ ou de l’objet.", ["REPORTED_VISIT"] = "Visiter cette position signalée", ["COMPLETED_BEFORE"] = "Déjà terminée auparavant", ["DETAIL_BACK"] = "Retour", ["REQUIREMENT_GROUPS"] = "Groupes de prérequis connus", ["REQUIREMENT_NOTICE"] = "Chaque groupe indiqué est requis ; une quête par groupe suffit. Des conditions supplémentaires peuvent être inconnues.", ["REQUIREMENT_GROUP"] = "Prérequis %d", ["REQUIREMENT_ACTIVE"] = "Accepter ou terminer une quête.", ["REQUIREMENT_COMPLETE"] = "Terminer une quête.", ["CATALOG_LEVELS"] = "Niveaux %d–%d", ["CATALOG_QUESTS"] = "Quêtes répertoriées : %d", ["OBJECTIVE_DIALOGUE"] = "Objectif du dialogue de quête ouvert", ["OBJECTIVE_PROGRESS"] = "Objectifs indiqués par le jeu", ["REWARD_DIALOGUE"] = "Récompenses du dialogue de quête ouvert", ["REWARD_HIDDEN"] = "Le client n’affiche pas les récompenses de cette quête.", ["REWARD_XP"] = "Expérience : %d",  ["OFFERED_NOW"] = "Proposée dans le dialogue actuel avec le PNJ.", ["ITEM_CLASSES"] = "Classes de l’objet : %s", ["ITEM_MIN_LEVEL"] = "L’objet nécessite le niveau %d.", ["ITEM_REQUIREMENTS_NOTICE"] = "Conditions de l’objet uniquement. La disponibilité de la quête est vérifiée séparément.", ["POSSIBLE_TURNINS"] = "Lieux de retour possibles — disponibilité non confirmée", ["STORY_GROUP"] = "Groupe narratif %d", ["STORY_GROUP_NOTICE"] = "La source présente ces quêtes ensemble. Cela ne confirme ni les prérequis ni les quêtes que votre personnage peut accepter.", ["START_ALTERNATIVES"] = "Départs possibles — disponibilité non confirmée", ["ITEM_STARTER"] = "Objet qui lance la quête : %s", ["ITEM_DROP_SOURCE"] = "Butin de %s dans %s.", ["QUEST_PORTRAIT"] = "Portrait de quête", ["REPEATABLE"] = "Quête répétable", ["MATERIAL_QUESTS"] = "Quêtes pour les matériaux requis", ["MATERIAL_ITEM"] = "Objet nº%d", ["MATERIAL_NOTICE"] = "Ces quêtes fournissent des matériaux pour terminer la quête, sans être des prérequis d’acceptation confirmés. Les avoir terminées ne prouve pas que vous possédez encore les objets.", ["SEARCH_HELP"] = "Recherchez des donjons, des quêtes répertoriées, des PNJ et des lieux connus, ou saisissez un ID de quête. La casse est ignorée ; accents et orthographe comptent.", ["NO_DUNGEONS"] = "Aucun donjon ne correspond à la recherche et aux filtres choisis.", ["REWARD_ITEMS"] = "Objets en récompense", ["REWARD_CHOICES"] = "Choisir un objet", ["REWARD_ITEM"] = "%s ×%d", ["REWARD_NO_ITEMS"] = "Aucun objet en récompense.", ["REWARD_UNAVAILABLE"] = "Les récompenses de cette quête ne sont pas disponibles.", ["REWARD_MONEY"] = "Argent", ["REWARD_MONEY_UNKNOWN"] = "La récompense en argent ne peut pas être affichée.", ["BRANCH_GROUP"] = "Prérequis %d : choisir une option", ["BRANCH_AUTO"] = "Automatique", ["BRANCH_SELECTED"] = "%s (sélectionné)", ["VISIT_GIVER"] = "Aller au donneur", ["GIVER_MAP"] = "Donneur sur la carte", ["LOCATION_ONLY"] = "Emplacement uniquement ; la disponibilité de la quête n’est pas confirmée.", ["NO_CHARACTER_QUESTS"] = "Aucune quête connue pour ce personnage. Passez à %s pour consulter les autres.", ["MY_CHARACTER"] = "Mon personnage", ["ALL_CHARACTERS"] = "Tous les persos", ["PREP_unavailable"] = "Indisponible pour ce personnage", ["REASON_requirements"] = "Des étapes de quête requises restent à accomplir.", ["REASON_requirementsUnknown"] = "Les prérequis de la quête ne sont pas encore entièrement vérifiés.", ["REASON_character"] = "L’historique des quêtes ou les restrictions du personnage n’ont pas pu être vérifiés.", ["REASON_level"] = "Niveau %d requis.", ["REASON_level_current"] = "Niveau %d requis ; niveau actuel : %d.", ["REASON_levelUnknown"] = "Votre niveau n’a pas pu être vérifié.", ["REASON_missing"] = "Les informations de cette quête sont absentes du catalogue.", ["REASON_cycle"] = "Les dépendances des quêtes forment une boucle ; la disponibilité reste indéterminée.", ["REASON_faction"] = "Votre faction ne remplit pas les conditions de cette quête.", ["REASON_class"] = "Votre classe ne remplit pas les conditions de cette quête.", ["REASON_race"] = "Votre race ne remplit pas les conditions de cette quête.", ["PREP_outside"] = "Accepter avant d’entrer", ["PREP_inside"] = "Accepter dans le donjon", ["PREP_level"] = "Niveaux requis", ["PREP_progress"] = "Terminer ou rendre", ["PREP_uncertain"] = "Prérequis encore inconnus", ["ACTIVE"] = "Dans le journal", ["ALL"] = "Tous les niveaux", ["AVAILABLE"] = "Disponible", ["CHAIN"] = "Suite de quêtes", ["CLEAR"] = "Retirer le guide", ["COMPLETED"] = "Terminée", ["COPY"] = "Sélectionnez le lien et appuyez sur Ctrl+C.", ["DEVELOPMENT"] = "Version de développement — couverture incomplète", ["EMPTY"] = "Les quêtes de ce donjon ne sont pas encore ajoutées.", ["ENDING"] = "Retour", ["GUIDE"] = "Indiquer la direction", ["LOCKED"] = "Préparation nécessaire", ["MAP"] = "Afficher sur la carte", ["NEXT"] = "Prochaine étape", ["NOT_PREPARED"] = "Préparation restante", ["NO_POSITION"] = "Position indisponible ou autre continent", ["NO_TEXT"] = "Le texte original de la quête est indisponible. Ouvrez la proposition de quête pour l’enregistrer.", ["ONLY_EN_RU"] = "Langue", ["PARTIAL"] = "La liste des quêtes est encore en cours de vérification", ["PICK"] = "Choisissez un donjon, puis une quête.", ["PREPARED"] = "Quêtes connues préparées", ["QUESTS"] = "Quêtes du donjon", ["RANGE"] = "Mon niveau", ["READY"] = "À rendre", ["SEARCH"] = "Donjon, quête, PNJ", ["SOURCE"] = "Lien Wowhead", ["START"] = "Départ", ["STORY"] = "Ordre du récit (prérequis en cours de vérification)", ["SUBTITLE"] = "Préparez votre prochaine visite", ["SUMMARY"] = "Acceptées : %d   Terminées : %d   Préparation : %d   Inconnues : %d", ["TITLE"] = "Dungeon Pro", ["UNAVAILABLE"] = "Indisponible pour ce personnage", ["UNKNOWN"] = "Informations insuffisantes", ["UNKNOWN_PLACE"] = "Emplacement encore inconnu", ["UNSUPPORTED"] = "Cette version prend uniquement en charge WoW Forever.", ["complete"] = "Terminer la quête", ["inside"] = "Accepter dans le donjon", ["level"] = "Atteindre le niveau", ["pickup"] = "Accepter", ["turnin"] = "Rendre" }
addon.locales.esES = { ["SEARCH_OBJECTIVE_MATCH"] = "Objetivo de misión: %s", ["SEARCH_NPC_MATCH"] = "PNJ: %s", ["SEARCH_PLACE_MATCH"] = "Lugar: %s", ["OBJECTIVE_ITEM_SOURCES"] = "Dónde encontrar objetos de misión", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "Fuentes indicadas; la disponibilidad de los objetos no está confirmada.", ["LANGUAGE_AUTO_SHORT"] = "Auto", ["QUEST_LEVEL"] = "Nivel de misión: %.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "Entrega: %s", ["DIALOGUE_PROGRESS_TEXT"] = "Diálogo actual de misión", ["DIALOGUE_TURNIN_TEXT"] = "Diálogo actual de entrega", ["GAME_WAYPOINT"] = "Punto de ruta del juego", ["GAME_WAYPOINT_NOTICE"] = "Este punto puede indicar una ruta, una entrada o dónde entregar una misión.", ["GAME_WAYPOINT_FOLLOW"] = "Seguir el punto del juego", ["QUEST_LOG_PAYMENT"] = "Pago en el registro de misiones: %s", ["PREPARATION_EMPTY"] = "No se muestran pasos de preparación. Cambia a %s para ver las misiones de la lista.", ["QUEST_PAYMENT"] = "Pago indicado: %s", ["MONEY_COPPER"] = "%.0f de cobre", ["QUEST_PAYMENT_NOTICE"] = "Este coste no confirma que la misión esté disponible.", ["SEARCH_QUEST_MATCH"] = "Misión: %s", ["STORY_SOURCE_QUESTS"] = "Misiones de la lista de la historia: %d", ["OBJECTIVE_OBJECTS"] = "Otros objetivos indicados", ["OBJECTIVE_OBJECTS_NOTICE"] = "La lista muestra objetivos de la misión, no requisitos de aceptación confirmados ni el progreso actual.", ["OPEN_QUEST_LOG"] = "Abrir en el registro", ["QUEST_TEXT"] = "Texto de la misión", ["ITEM_DROP_LOCATIONS"] = "Lugares de obtención conocidos — disponibilidad sin confirmar", ["ITEM_ACQUISITION"] = "Conseguir el objeto que inicia la misión", ["ITEM_ACQUISITION_UNKNOWN"] = "Aún no se ha verificado dónde conseguir este objeto.", ["PROVIDED_ITEMS"] = "Objetos proporcionados para la misión", ["PROVIDED_ITEMS_NOTICE"] = "Los objetos proporcionados pueden usarse o consumirse durante la misión. La cantidad que llevas se muestra por separado.", ["OBJECTIVE_KILLS"] = "Objetivos de eliminación indicados", ["OBJECTIVE_KILLS_NOTICE"] = "Los objetivos indicados pertenecen a la misión; no son condiciones confirmadas para aceptarla ni el progreso actual.", ["GIVER_REFERENCE_PORTRAIT"] = "Dador de misiones: %s", ["QUEST_FACTIONS"] = "Facciones: %s", ["PREPARATION_FOR"] = "Preparación para", ["PREPARATION_FOR_NOTICE"] = "Objetivos del plan de preparación actual; puede haber otras rutas.", ["LANGUAGE_AUTO"] = "Automático (idioma del juego)", ["GUIDE_DISTANCE"] = "%.0f yd", ["BRANCH_INSPECT"] = "Ver misión", ["OVERVIEW_PICK"] = "Selecciona una misión de la lista para ver sus detalles y pasos de preparación.", ["OVERVIEW_REVIEWED"] = "Lista de misiones revisada; algunos requisitos pueden seguir sin verificar.", ["FACTION_Alliance"] = "Alianza", ["FACTION_Horde"] = "Horda", ["FACTION_Neutral"] = "Neutral", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — cantidad sin verificar", ["MINIMAP_OPEN"] = "Clic izquierdo: abrir o cerrar Dungeon Pro.", ["MINIMAP_DRAG"] = "Arrastra el icono alrededor del minimapa.", ["OBJECTIVE_ITEMS"] = "Objetivos de objetos indicados", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "Los objetos indicados son objetivos de misión, no condiciones de aceptación confirmadas ni el progreso actual.",  ["QUEST_MIN_LEVEL"] = "Nivel mínimo: %.0f", ["QUEST_CLASSES"] = "Clases: %s", ["QUEST_RACES"] = "Razas: %s", ["RACE_ID"] = "Raza n.º %.0f",  ["QUEST_LOG_CAPACITY"] = "Registro de misiones: %.0f/%.0f", ["ITEM_CARRIED"] = "En tu poder: %.0f", ["DUNGEON_WING_lower"] = "%s — Ala inferior", ["DUNGEON_WING_upper"] = "%s — Ala superior", ["REWARD_PREVIEW"] = "Vista previa de recompensas de misión", ["UNKNOWN_REQUIREMENTS"] = "No está en el registro — requisitos sin verificar", ["CONTAINER_SOURCE"] = "Contenedor conocido del objeto — disponibilidad sin confirmar", ["REPORTED_POSITIONS"] = "Posiciones registradas: %s (%d)", ["REPORTED_NOTICE"] = "Estos puntos pueden reflejar movimientos o fases de misión. No confirman la ubicación actual del PNJ o del objeto.", ["REPORTED_VISIT"] = "Visitar esta posición registrada", ["COMPLETED_BEFORE"] = "Completada anteriormente", ["DETAIL_BACK"] = "Atrás", ["REQUIREMENT_GROUPS"] = "Grupos de requisitos conocidos", ["REQUIREMENT_NOTICE"] = "Se requiere cada grupo indicado; basta una misión por grupo. Puede haber requisitos adicionales desconocidos.", ["REQUIREMENT_GROUP"] = "Requisito %d", ["REQUIREMENT_ACTIVE"] = "Aceptar o completar una misión.", ["REQUIREMENT_COMPLETE"] = "Completar una misión.", ["CATALOG_LEVELS"] = "Niveles %d–%d", ["CATALOG_QUESTS"] = "Misiones listadas: %d", ["OBJECTIVE_DIALOGUE"] = "Objetivo del diálogo de misión abierto", ["OBJECTIVE_PROGRESS"] = "Objetivos indicados por el juego", ["REWARD_DIALOGUE"] = "Recompensas del diálogo de misión abierto", ["REWARD_HIDDEN"] = "El cliente no muestra las recompensas de esta misión.", ["REWARD_XP"] = "Experiencia: %d",  ["OFFERED_NOW"] = "Se ofrece en el diálogo actual con el PNJ.", ["ITEM_CLASSES"] = "Clases del objeto: %s", ["ITEM_MIN_LEVEL"] = "El objeto requiere nivel %d.", ["ITEM_REQUIREMENTS_NOTICE"] = "Solo requisitos del objeto. La disponibilidad de la misión se comprueba por separado.", ["POSSIBLE_TURNINS"] = "Posibles puntos de entrega — disponibilidad sin confirmar", ["STORY_GROUP"] = "Grupo de historia %d", ["STORY_GROUP_NOTICE"] = "La fuente muestra estas misiones juntas. Esto no confirma los requisitos ni qué misiones puede aceptar tu personaje.", ["START_ALTERNATIVES"] = "Posibles puntos de inicio — disponibilidad sin confirmar", ["ITEM_STARTER"] = "Objeto que inicia la misión: %s", ["ITEM_DROP_SOURCE"] = "Lo suelta %s en %s.", ["QUEST_PORTRAIT"] = "Retrato de misión", ["REPEATABLE"] = "Misión repetible", ["MATERIAL_QUESTS"] = "Misiones de materiales requeridos", ["MATERIAL_ITEM"] = "Objeto n.º%d", ["MATERIAL_NOTICE"] = "Estas misiones dan materiales para completarla, pero no son requisitos confirmados para aceptarla. Completarlas no confirma que aún tengas sus objetos.", ["SEARCH_HELP"] = "Busca mazmorras, misiones indicadas, PNJ y lugares registrados, o introduce un ID de misión. No se distinguen mayúsculas; los acentos y la escritura importan.", ["NO_DUNGEONS"] = "Ninguna mazmorra coincide con la búsqueda y los filtros elegidos.", ["REWARD_ITEMS"] = "Objetos de recompensa", ["REWARD_CHOICES"] = "Elige un objeto", ["REWARD_ITEM"] = "%s ×%d", ["REWARD_NO_ITEMS"] = "No hay objetos de recompensa.", ["REWARD_UNAVAILABLE"] = "Los datos de recompensa de esta misión no están disponibles.", ["REWARD_MONEY"] = "Dinero", ["REWARD_MONEY_UNKNOWN"] = "No se ha podido mostrar la recompensa de dinero.", ["BRANCH_GROUP"] = "Requisito %d: elige una opción", ["BRANCH_AUTO"] = "Automático", ["BRANCH_SELECTED"] = "%s (seleccionado)", ["VISIT_GIVER"] = "Ir al dador de misión", ["GIVER_MAP"] = "Dador en el mapa", ["LOCATION_ONLY"] = "Solo ubicación; la disponibilidad de la misión no está confirmada.", ["NO_CHARACTER_QUESTS"] = "No hay misiones conocidas para este personaje. Cambia a %s para ver las demás.", ["MY_CHARACTER"] = "Mi personaje", ["ALL_CHARACTERS"] = "Todos", ["PREP_unavailable"] = "No disponible para este personaje", ["REASON_requirements"] = "Aún quedan pasos de misión requeridos por completar.", ["REASON_requirementsUnknown"] = "Los requisitos de la misión aún no se han verificado por completo.", ["REASON_character"] = "No se ha podido comprobar el historial de misiones o las restricciones del personaje.", ["REASON_level"] = "Requiere nivel %d.", ["REASON_level_current"] = "Requiere nivel %d; nivel actual: %d.", ["REASON_levelUnknown"] = "No se ha podido comprobar tu nivel.", ["REASON_missing"] = "Falta información de esta misión en el catálogo.", ["REASON_cycle"] = "Las dependencias de misiones forman un ciclo; no se puede determinar la disponibilidad.", ["REASON_faction"] = "Tu facción no cumple los requisitos de esta misión.", ["REASON_class"] = "Tu clase no cumple los requisitos de esta misión.", ["REASON_race"] = "Tu raza no cumple los requisitos de esta misión.", ["PREP_outside"] = "Aceptar antes de entrar", ["PREP_inside"] = "Aceptar dentro de la mazmorra", ["PREP_level"] = "Requisitos de nivel", ["PREP_progress"] = "Completar o entregar", ["PREP_uncertain"] = "Requisitos aún desconocidos", ["ACTIVE"] = "En el registro", ["ALL"] = "Todos los niveles", ["AVAILABLE"] = "Disponible", ["CHAIN"] = "Cadena de misiones", ["CLEAR"] = "Quitar guía", ["COMPLETED"] = "Completada", ["COPY"] = "Selecciona el enlace y pulsa Ctrl+C.", ["DEVELOPMENT"] = "Versión en desarrollo — cobertura incompleta", ["EMPTY"] = "Todavía no hay datos de misiones para esta mazmorra.", ["ENDING"] = "Entrega", ["GUIDE"] = "Indicar dirección", ["LOCKED"] = "Requiere preparación", ["MAP"] = "Mostrar en el mapa", ["NEXT"] = "Siguiente paso", ["NOT_PREPARED"] = "Preparación pendiente", ["NO_POSITION"] = "Posición no disponible o destino en otro continente", ["NO_TEXT"] = "El texto original de la misión no está disponible. Abre la oferta de la misión para guardarlo.", ["ONLY_EN_RU"] = "Idioma", ["PARTIAL"] = "Se está comprobando la lista de misiones", ["PICK"] = "Elige una mazmorra y una misión.", ["PREPARED"] = "Misiones conocidas preparadas", ["QUESTS"] = "Misiones de mazmorra", ["RANGE"] = "Mi nivel", ["READY"] = "Lista para entregar", ["SEARCH"] = "Mazmorra, misión, PNJ", ["SOURCE"] = "Enlace de Wowhead", ["START"] = "Inicio", ["STORY"] = "Orden de la historia (requisitos en revisión)", ["SUBTITLE"] = "Prepárate antes de entrar", ["SUMMARY"] = "Aceptadas: %d   Completadas: %d   Preparación: %d   Desconocidas: %d", ["TITLE"] = "Dungeon Pro", ["UNAVAILABLE"] = "No disponible para este personaje", ["UNKNOWN"] = "Información insuficiente", ["UNKNOWN_PLACE"] = "Ubicación aún desconocida", ["UNSUPPORTED"] = "Esta versión solo es compatible con WoW Forever.", ["complete"] = "Completar misión", ["inside"] = "Aceptar dentro de la mazmorra", ["level"] = "Alcanzar nivel", ["pickup"] = "Aceptar", ["turnin"] = "Entregar" }
addon.locales.itIT = { ["SEARCH_OBJECTIVE_MATCH"] = "Obiettivo della missione: %s", ["SEARCH_NPC_MATCH"] = "PNG: %s", ["SEARCH_PLACE_MATCH"] = "Luogo: %s", ["OBJECTIVE_ITEM_SOURCES"] = "Dove trovare gli oggetti di missione", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "Fonti segnalate; la disponibilità degli oggetti non è confermata.", ["LANGUAGE_AUTO_SHORT"] = "Auto", ["QUEST_LEVEL"] = "Livello missione: %.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "Consegna: %s", ["DIALOGUE_PROGRESS_TEXT"] = "Dialogo attuale della missione", ["DIALOGUE_TURNIN_TEXT"] = "Dialogo attuale di consegna", ["GAME_WAYPOINT"] = "Punto di percorso del gioco", ["GAME_WAYPOINT_NOTICE"] = "Il punto può indicare un percorso, un ingresso o dove consegnare una missione.", ["GAME_WAYPOINT_FOLLOW"] = "Segui il punto del gioco", ["QUEST_LOG_PAYMENT"] = "Pagamento nel registro missioni: %s", ["PREPARATION_EMPTY"] = "Non sono mostrate fasi di preparazione. Passa a %s per vedere le missioni elencate.", ["QUEST_PAYMENT"] = "Pagamento indicato: %s", ["MONEY_COPPER"] = "%.0f rame", ["QUEST_PAYMENT_NOTICE"] = "Questo costo non conferma la disponibilità della missione.", ["SEARCH_QUEST_MATCH"] = "Missione: %s", ["STORY_SOURCE_QUESTS"] = "Missioni nella storia: %d", ["OBJECTIVE_OBJECTS"] = "Altri obiettivi elencati", ["OBJECTIVE_OBJECTS_NOTICE"] = "Queste attività sono obiettivi della missione, non requisiti confermati per accettarla né indicazioni sui progressi attuali.", ["OPEN_QUEST_LOG"] = "Apri nel registro missioni", ["QUEST_TEXT"] = "Testo della missione", ["ITEM_DROP_LOCATIONS"] = "Luoghi di ritrovamento noti — disponibilità non confermata", ["ITEM_ACQUISITION"] = "Ottenere l’oggetto che avvia la missione", ["ITEM_ACQUISITION_UNKNOWN"] = "La provenienza di questo oggetto non è ancora stata verificata.", ["PROVIDED_ITEMS"] = "Oggetti forniti per la missione", ["PROVIDED_ITEMS_NOTICE"] = "Gli oggetti forniti possono essere usati o consumati durante la missione. La quantità attualmente posseduta è mostrata separatamente.", ["OBJECTIVE_KILLS"] = "Obiettivi di uccisione elencati", ["OBJECTIVE_KILLS_NOTICE"] = "I bersagli elencati sono obiettivi della missione, non condizioni confermate per accettarla né progressi attuali.", ["GIVER_REFERENCE_PORTRAIT"] = "Assegnatore della missione: %s", ["QUEST_FACTIONS"] = "Fazioni: %s", ["PREPARATION_FOR"] = "Preparazione per", ["PREPARATION_FOR_NOTICE"] = "Obiettivi del piano di preparazione attuale; potrebbero esserci altre vie.", ["LANGUAGE_AUTO"] = "Automatico (lingua del gioco)", ["GUIDE_DISTANCE"] = "%.0f yd", ["BRANCH_INSPECT"] = "Vedi missione", ["OVERVIEW_PICK"] = "Seleziona una missione elencata per vederne i dettagli e i passaggi di preparazione.", ["OVERVIEW_REVIEWED"] = "Elenco missioni verificato; alcuni requisiti potrebbero non essere ancora confermati.", ["FACTION_Alliance"] = "Alleanza", ["FACTION_Horde"] = "Orda", ["FACTION_Neutral"] = "Neutrale", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — quantità non verificata", ["MINIMAP_OPEN"] = "Clic sinistro: apri o chiudi Dungeon Pro.", ["MINIMAP_DRAG"] = "Trascina l’icona attorno alla minimappa.", ["OBJECTIVE_ITEMS"] = "Obiettivi oggetto elencati", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "Gli oggetti elencati sono obiettivi della missione, non condizioni confermate per accettarla né il progresso attuale.",  ["QUEST_MIN_LEVEL"] = "Livello minimo: %.0f", ["QUEST_CLASSES"] = "Classi: %s", ["QUEST_RACES"] = "Razze: %s", ["RACE_ID"] = "Razza n. %.0f",  ["QUEST_LOG_CAPACITY"] = "Registro missioni: %.0f/%.0f", ["ITEM_CARRIED"] = "Con te: %.0f", ["DUNGEON_WING_lower"] = "%s — Ala inferiore", ["DUNGEON_WING_upper"] = "%s — Ala superiore", ["REWARD_PREVIEW"] = "Anteprima delle ricompense della missione", ["UNKNOWN_REQUIREMENTS"] = "Non nel registro — requisiti non verificati", ["CONTAINER_SOURCE"] = "Contenitore noto dell’oggetto — disponibilità non confermata", ["REPORTED_POSITIONS"] = "Posizioni segnalate: %s (%d)", ["REPORTED_NOTICE"] = "Questi punti possono riflettere spostamenti o fasi della missione. Non confermano la posizione attuale del PNG o dell’oggetto.", ["REPORTED_VISIT"] = "Visita questa posizione segnalata", ["COMPLETED_BEFORE"] = "Completata in precedenza", ["DETAIL_BACK"] = "Indietro", ["REQUIREMENT_GROUPS"] = "Gruppi di prerequisiti noti", ["REQUIREMENT_NOTICE"] = "Ogni gruppo elencato è richiesto; basta una missione per gruppo. Altri requisiti potrebbero essere sconosciuti.", ["REQUIREMENT_GROUP"] = "Requisito %d", ["REQUIREMENT_ACTIVE"] = "Accetta o completa una missione.", ["REQUIREMENT_COMPLETE"] = "Completa una missione.", ["CATALOG_LEVELS"] = "Livelli %d–%d", ["CATALOG_QUESTS"] = "Missioni elencate: %d", ["OBJECTIVE_DIALOGUE"] = "Obiettivo nel dialogo di missione aperto", ["OBJECTIVE_PROGRESS"] = "Obiettivi indicati dal gioco", ["REWARD_DIALOGUE"] = "Ricompense nel dialogo della missione aperto", ["REWARD_HIDDEN"] = "Il client non mostra le ricompense di questa missione.", ["REWARD_XP"] = "Esperienza: %d",  ["OFFERED_NOW"] = "Offerta nel dialogo attuale con il PNG.", ["ITEM_CLASSES"] = "Classi dell'oggetto: %s", ["ITEM_MIN_LEVEL"] = "L'oggetto richiede il livello %d.", ["ITEM_REQUIREMENTS_NOTICE"] = "Solo requisiti dell'oggetto. La disponibilità della missione viene verificata separatamente.", ["POSSIBLE_TURNINS"] = "Possibili punti di consegna — disponibilità non confermata", ["STORY_GROUP"] = "Gruppo narrativo %d", ["STORY_GROUP_NOTICE"] = "La fonte mostra queste missioni insieme. Ciò non conferma i prerequisiti né quali missioni può accettare il tuo personaggio.", ["START_ALTERNATIVES"] = "Possibili punti iniziali — disponibilità non confermata", ["ITEM_STARTER"] = "Oggetto che avvia la missione: %s", ["ITEM_DROP_SOURCE"] = "Ottenibile da %s in %s.", ["QUEST_PORTRAIT"] = "Ritratto della missione", ["REPEATABLE"] = "Missione ripetibile", ["MATERIAL_QUESTS"] = "Missioni per i materiali richiesti", ["MATERIAL_ITEM"] = "Oggetto n.%d", ["MATERIAL_NOTICE"] = "Queste missioni forniscono materiali per il completamento, non requisiti confermati per accettarla. Averle completate non conferma che possiedi ancora gli oggetti.", ["SEARCH_HELP"] = "Cerca spedizioni, missioni elencate, PNG e luoghi registrati, oppure inserisci un ID missione. Le maiuscole non contano; accenti e ortografia sì.", ["NO_DUNGEONS"] = "Nessuna spedizione corrisponde alla ricerca e ai filtri selezionati.", ["REWARD_ITEMS"] = "Oggetti in ricompensa", ["REWARD_CHOICES"] = "Scegli un oggetto", ["REWARD_ITEM"] = "%s ×%d", ["REWARD_NO_ITEMS"] = "Nessun oggetto in ricompensa.", ["REWARD_UNAVAILABLE"] = "I dati delle ricompense di questa missione non sono disponibili.", ["REWARD_MONEY"] = "Denaro", ["REWARD_MONEY_UNKNOWN"] = "Impossibile mostrare la ricompensa in denaro.", ["BRANCH_GROUP"] = "Requisito %d: scegli un’opzione", ["BRANCH_AUTO"] = "Automatico", ["BRANCH_SELECTED"] = "%s (selezionato)", ["VISIT_GIVER"] = "Vai dal committente", ["GIVER_MAP"] = "Committente sulla mappa", ["LOCATION_ONLY"] = "Solo posizione; la disponibilità della missione non è confermata.", ["NO_CHARACTER_QUESTS"] = "Nessuna missione nota per questo personaggio. Passa a %s per vedere le altre.", ["MY_CHARACTER"] = "Mio personaggio", ["ALL_CHARACTERS"] = "Tutti", ["PREP_unavailable"] = "Non per questo personaggio", ["REASON_requirements"] = "Alcuni passaggi delle missioni richieste sono ancora da completare.", ["REASON_requirementsUnknown"] = "I requisiti della missione non sono ancora stati verificati completamente.", ["REASON_character"] = "Impossibile verificare la cronologia delle missioni o le restrizioni del personaggio.", ["REASON_level"] = "Richiede il livello %d.", ["REASON_level_current"] = "Richiede il livello %d; livello attuale: %d.", ["REASON_levelUnknown"] = "Impossibile verificare il tuo livello.", ["REASON_missing"] = "Le informazioni su questa missione mancano nel catalogo.", ["REASON_cycle"] = "Le dipendenze delle missioni formano un ciclo; la disponibilità non è determinabile.", ["REASON_faction"] = "La tua fazione non soddisfa i requisiti della missione.", ["REASON_class"] = "La tua classe non soddisfa i requisiti della missione.", ["REASON_race"] = "La tua razza non soddisfa i requisiti della missione.", ["PREP_outside"] = "Accetta prima di entrare", ["PREP_inside"] = "Accetta nella spedizione", ["PREP_level"] = "Requisiti di livello", ["PREP_progress"] = "Completa o consegna", ["PREP_uncertain"] = "Requisiti ancora sconosciuti", ["ACTIVE"] = "Nel registro", ["ALL"] = "Tutti i livelli", ["AVAILABLE"] = "Disponibile", ["CHAIN"] = "Serie di missioni", ["CLEAR"] = "Rimuovi guida", ["COMPLETED"] = "Completata", ["COPY"] = "Seleziona il link e premi Ctrl+C.", ["DEVELOPMENT"] = "Versione di sviluppo — copertura incompleta", ["EMPTY"] = "Le missioni di questa spedizione non sono ancora state aggiunte.", ["ENDING"] = "Consegna", ["GUIDE"] = "Indica direzione", ["LOCKED"] = "Preparazione necessaria", ["MAP"] = "Mostra sulla mappa", ["NEXT"] = "Prossimo passo", ["NOT_PREPARED"] = "Preparazione rimanente", ["NO_POSITION"] = "Posizione non disponibile o altro continente", ["NO_TEXT"] = "Il testo originale della missione non è disponibile. Apri l'offerta della missione per salvarlo.", ["ONLY_EN_RU"] = "Lingua", ["PARTIAL"] = "Completezza delle missioni in verifica", ["PICK"] = "Scegli una spedizione e una missione.", ["PREPARED"] = "Missioni conosciute preparate", ["QUESTS"] = "Missioni della spedizione", ["RANGE"] = "Il mio livello", ["READY"] = "Pronta da consegnare", ["SEARCH"] = "Spedizione, missione, PNG", ["SOURCE"] = "Link Wowhead", ["START"] = "Inizio", ["STORY"] = "Ordine della storia (requisiti in verifica)", ["SUBTITLE"] = "Preparati prima di entrare", ["SUMMARY"] = "Accettate: %d   Completate: %d   Preparazione: %d   Sconosciute: %d", ["TITLE"] = "Dungeon Pro", ["UNAVAILABLE"] = "Non per questo personaggio", ["UNKNOWN"] = "Informazioni insufficienti", ["UNKNOWN_PLACE"] = "Posizione ancora sconosciuta", ["UNSUPPORTED"] = "Questa versione supporta solo WoW Forever.", ["complete"] = "Completa la missione", ["inside"] = "Accetta nella spedizione", ["level"] = "Raggiungi livello", ["pickup"] = "Accetta", ["turnin"] = "Consegna" }
addon.locales.ptBR = { ["SEARCH_OBJECTIVE_MATCH"] = "Objetivo da missão: %s", ["SEARCH_NPC_MATCH"] = "PNJ: %s", ["SEARCH_PLACE_MATCH"] = "Local: %s", ["OBJECTIVE_ITEM_SOURCES"] = "Onde encontrar itens de missão", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "Fontes informadas; a disponibilidade dos itens não está confirmada.", ["LANGUAGE_AUTO_SHORT"] = "Auto", ["QUEST_LEVEL"] = "Nível da missão: %.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "Entrega: %s", ["DIALOGUE_PROGRESS_TEXT"] = "Diálogo atual da missão", ["DIALOGUE_TURNIN_TEXT"] = "Diálogo atual de entrega", ["GAME_WAYPOINT"] = "Ponto de rota do jogo", ["GAME_WAYPOINT_NOTICE"] = "O ponto pode indicar uma rota, uma entrada ou um local de entrega da missão.", ["GAME_WAYPOINT_FOLLOW"] = "Seguir ponto do jogo", ["QUEST_LOG_PAYMENT"] = "Pagamento no registro de missões: %s", ["PREPARATION_EMPTY"] = "Nenhuma etapa de preparação é exibida. Mude para %s para ver as missões listadas.", ["QUEST_PAYMENT"] = "Pagamento indicado: %s", ["MONEY_COPPER"] = "%.0f de cobre", ["QUEST_PAYMENT_NOTICE"] = "Este custo não confirma a disponibilidade da missão.", ["SEARCH_QUEST_MATCH"] = "Missão: %s", ["STORY_SOURCE_QUESTS"] = "Missões na lista da história: %d", ["OBJECTIVE_OBJECTS"] = "Outros objetivos listados", ["OBJECTIVE_OBJECTS_NOTICE"] = "Estas tarefas são objetivos da missão, não condições confirmadas para aceitá-la nem o progresso atual.", ["OPEN_QUEST_LOG"] = "Abrir no registro de missões", ["QUEST_TEXT"] = "Texto da missão", ["ITEM_DROP_LOCATIONS"] = "Locais conhecidos de obtenção — disponibilidade não confirmada", ["ITEM_ACQUISITION"] = "Conseguir o item que inicia a missão", ["ITEM_ACQUISITION_UNKNOWN"] = "A origem deste item ainda não foi verificada.", ["PROVIDED_ITEMS"] = "Itens fornecidos para a missão", ["PROVIDED_ITEMS_NOTICE"] = "Os itens fornecidos podem ser usados ou consumidos durante a missão. A quantidade atual em sua posse é mostrada separadamente.", ["OBJECTIVE_KILLS"] = "Objetivos de abate listados", ["OBJECTIVE_KILLS_NOTICE"] = "Os alvos listados são objetivos da missão, não condições confirmadas para aceitá-la nem o progresso atual.", ["GIVER_REFERENCE_PORTRAIT"] = "Concedente da missão: %s", ["QUEST_FACTIONS"] = "Facções: %s", ["PREPARATION_FOR"] = "Preparação para", ["PREPARATION_FOR_NOTICE"] = "Objetivos do plano de preparação atual; outras rotas podem ser possíveis.", ["LANGUAGE_AUTO"] = "Automático (idioma do jogo)", ["GUIDE_DISTANCE"] = "%.0f yd", ["BRANCH_INSPECT"] = "Ver missão", ["OVERVIEW_PICK"] = "Selecione uma missão da lista para ver os detalhes e as etapas de preparação.", ["OVERVIEW_REVIEWED"] = "Lista de missões revisada; alguns requisitos ainda podem não estar confirmados.", ["FACTION_Alliance"] = "Aliança", ["FACTION_Horde"] = "Horda", ["FACTION_Neutral"] = "Neutro", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — quantidade não verificada", ["MINIMAP_OPEN"] = "Clique esquerdo: abrir ou fechar o Dungeon Pro.", ["MINIMAP_DRAG"] = "Arraste o ícone ao redor do minimapa.", ["OBJECTIVE_ITEMS"] = "Objetivos de itens listados", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "Os itens listados são objetivos da missão, não condições confirmadas para aceitá-la nem o progresso atual.",  ["QUEST_MIN_LEVEL"] = "Nível mínimo: %.0f", ["QUEST_CLASSES"] = "Classes: %s", ["QUEST_RACES"] = "Raças: %s", ["RACE_ID"] = "Raça nº %.0f",  ["QUEST_LOG_CAPACITY"] = "Registro de missões: %.0f/%.0f", ["ITEM_CARRIED"] = "Com você: %.0f", ["DUNGEON_WING_lower"] = "%s — Ala inferior", ["DUNGEON_WING_upper"] = "%s — Ala superior", ["REWARD_PREVIEW"] = "Prévia das recompensas da missão", ["UNKNOWN_REQUIREMENTS"] = "Fora do registro — requisitos não verificados", ["CONTAINER_SOURCE"] = "Recipiente conhecido do item — disponibilidade não confirmada", ["REPORTED_POSITIONS"] = "Posições registradas: %s (%d)", ["REPORTED_NOTICE"] = "Estes pontos podem refletir movimentos ou fases da missão. Eles não confirmam a posição atual do PNJ ou objeto.", ["REPORTED_VISIT"] = "Visitar esta posição registrada", ["COMPLETED_BEFORE"] = "Concluída anteriormente", ["DETAIL_BACK"] = "Voltar", ["REQUIREMENT_GROUPS"] = "Grupos de pré-requisitos conhecidos", ["REQUIREMENT_NOTICE"] = "Cada grupo listado é necessário; basta uma missão por grupo. Pode haver requisitos adicionais desconhecidos.", ["REQUIREMENT_GROUP"] = "Requisito %d", ["REQUIREMENT_ACTIVE"] = "Aceite ou conclua uma missão.", ["REQUIREMENT_COMPLETE"] = "Conclua uma missão.", ["CATALOG_LEVELS"] = "Níveis %d–%d", ["CATALOG_QUESTS"] = "Missões listadas: %d", ["OBJECTIVE_DIALOGUE"] = "Objetivo no diálogo de missão aberto", ["OBJECTIVE_PROGRESS"] = "Objetivos informados pelo jogo", ["REWARD_DIALOGUE"] = "Recompensas no diálogo da missão aberto", ["REWARD_HIDDEN"] = "O cliente não mostra as recompensas desta missão.", ["REWARD_XP"] = "Experiência: %d",  ["OFFERED_NOW"] = "Oferecida no diálogo atual com o PNJ.", ["ITEM_CLASSES"] = "Classes do item: %s", ["ITEM_MIN_LEVEL"] = "O item requer nível %d.", ["ITEM_REQUIREMENTS_NOTICE"] = "Apenas requisitos do item. A disponibilidade da missão é verificada separadamente.", ["POSSIBLE_TURNINS"] = "Possíveis pontos de entrega — disponibilidade não confirmada", ["STORY_GROUP"] = "Grupo da história %d", ["STORY_GROUP_NOTICE"] = "A fonte mostra estas missões juntas. Isso não confirma os requisitos nem quais missões seu personagem pode aceitar.", ["START_ALTERNATIVES"] = "Possíveis pontos de início — disponibilidade não confirmada", ["ITEM_STARTER"] = "Item que inicia a missão: %s", ["ITEM_DROP_SOURCE"] = "Obtido de %s em %s.", ["QUEST_PORTRAIT"] = "Retrato da missão", ["REPEATABLE"] = "Missão repetível", ["MATERIAL_QUESTS"] = "Missões de materiais necessários", ["MATERIAL_ITEM"] = "Item nº%d", ["MATERIAL_NOTICE"] = "Estas missões fornecem materiais para conclusão, não requisitos confirmados para aceitar a missão. Concluí-las não confirma que você ainda possui os itens.", ["SEARCH_HELP"] = "Busque masmorras, missões listadas, PNJs e locais registrados, ou digite um ID de missão. Maiúsculas não fazem diferença; acentos e grafia importam.", ["NO_DUNGEONS"] = "Nenhuma masmorra corresponde à busca e aos filtros selecionados.", ["REWARD_ITEMS"] = "Itens de recompensa", ["REWARD_CHOICES"] = "Escolha um item", ["REWARD_ITEM"] = "%s ×%d", ["REWARD_NO_ITEMS"] = "Nenhum item de recompensa.", ["REWARD_UNAVAILABLE"] = "Os dados de recompensa desta missão não estão disponíveis.", ["REWARD_MONEY"] = "Dinheiro", ["REWARD_MONEY_UNKNOWN"] = "Não foi possível exibir a recompensa em dinheiro.", ["BRANCH_GROUP"] = "Requisito %d: escolha uma opção", ["BRANCH_AUTO"] = "Automático", ["BRANCH_SELECTED"] = "%s (selecionado)", ["VISIT_GIVER"] = "Visitar quem dá a missão", ["GIVER_MAP"] = "Quem oferece no mapa", ["LOCATION_ONLY"] = "Apenas localização; a disponibilidade da missão não está confirmada.", ["NO_CHARACTER_QUESTS"] = "Não há missões conhecidas para este personagem. Mude para %s para ver as outras.", ["MY_CHARACTER"] = "Meu personagem", ["ALL_CHARACTERS"] = "Todos", ["PREP_unavailable"] = "Indisponível para este personagem", ["REASON_requirements"] = "Ainda há etapas de missão necessárias por concluir.", ["REASON_requirementsUnknown"] = "Os requisitos da missão ainda não foram totalmente verificados.", ["REASON_character"] = "Não foi possível verificar o histórico de missões ou as restrições do personagem.", ["REASON_level"] = "Requer nível %d.", ["REASON_level_current"] = "Requer nível %d; nível atual: %d.", ["REASON_levelUnknown"] = "Não foi possível verificar seu nível.", ["REASON_missing"] = "Faltam informações desta missão no catálogo.", ["REASON_cycle"] = "As dependências das missões formam um ciclo; não é possível determinar a disponibilidade.", ["REASON_faction"] = "Sua facção não atende aos requisitos desta missão.", ["REASON_class"] = "Sua classe não atende aos requisitos desta missão.", ["REASON_race"] = "Sua raça não atende aos requisitos desta missão.", ["PREP_outside"] = "Aceitar antes de entrar", ["PREP_inside"] = "Aceitar dentro da masmorra", ["PREP_level"] = "Requisitos de nível", ["PREP_progress"] = "Concluir ou entregar", ["PREP_uncertain"] = "Requisitos ainda desconhecidos", ["ACTIVE"] = "No registro", ["ALL"] = "Todos os níveis", ["AVAILABLE"] = "Disponível", ["CHAIN"] = "Sequência de missões", ["CLEAR"] = "Remover guia", ["COMPLETED"] = "Concluída", ["COPY"] = "Selecione o link e pressione Ctrl+C.", ["DEVELOPMENT"] = "Versão em desenvolvimento — cobertura incompleta", ["EMPTY"] = "As missões desta masmorra ainda não foram adicionadas.", ["ENDING"] = "Entrega", ["GUIDE"] = "Indicar direção", ["LOCKED"] = "Preparação necessária", ["MAP"] = "Mostrar no mapa", ["NEXT"] = "Próxima etapa", ["NOT_PREPARED"] = "Preparação pendente", ["NO_POSITION"] = "Posição indisponível ou destino em outro continente", ["NO_TEXT"] = "O texto original da missão não está disponível. Abra a oferta da missão para salvá-lo.", ["ONLY_EN_RU"] = "Idioma", ["PARTIAL"] = "A lista de missões ainda está sendo verificada", ["PICK"] = "Escolha uma masmorra e uma missão.", ["PREPARED"] = "Missões conhecidas preparadas", ["QUESTS"] = "Missões da masmorra", ["RANGE"] = "Meu nível", ["READY"] = "Pronta para entregar", ["SEARCH"] = "Masmorra, missão, PNJ", ["SOURCE"] = "Link do Wowhead", ["START"] = "Início", ["STORY"] = "Ordem da história (requisitos em análise)", ["SUBTITLE"] = "Prepare-se antes de entrar", ["SUMMARY"] = "Aceitas: %d   Concluídas: %d   Preparação: %d   Desconhecidas: %d", ["TITLE"] = "Dungeon Pro", ["UNAVAILABLE"] = "Indisponível para este personagem", ["UNKNOWN"] = "Informações insuficientes", ["UNKNOWN_PLACE"] = "Local ainda desconhecido", ["UNSUPPORTED"] = "Esta versão só oferece suporte ao WoW Forever.", ["complete"] = "Concluir missão", ["inside"] = "Aceitar dentro da masmorra", ["level"] = "Atingir nível", ["pickup"] = "Aceitar", ["turnin"] = "Entregar" }
addon.locales.koKR = { ["SEARCH_OBJECTIVE_MATCH"] = "퀘스트 목표: %s", ["SEARCH_NPC_MATCH"] = "NPC: %s", ["SEARCH_PLACE_MATCH"] = "장소: %s", ["OBJECTIVE_ITEM_SOURCES"] = "퀘스트 아이템 획득 장소", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "알려진 아이템 획득처이며, 현재 획득 가능 여부는 확인되지 않았습니다.", ["LANGUAGE_AUTO_SHORT"] = "자동", ["QUEST_LEVEL"] = "퀘스트 레벨: %.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "퀘스트 제출: %s", ["DIALOGUE_PROGRESS_TEXT"] = "현재 퀘스트 대화", ["DIALOGUE_TURNIN_TEXT"] = "현재 퀘스트 제출 대화", ["GAME_WAYPOINT"] = "게임 경유지", ["GAME_WAYPOINT_NOTICE"] = "경유지는 이동 경로, 입구 또는 퀘스트 완료 장소를 가리킬 수 있습니다.", ["GAME_WAYPOINT_FOLLOW"] = "게임 경유지 따라가기", ["QUEST_LOG_PAYMENT"] = "퀘스트 기록의 지불액: %s", ["PREPARATION_EMPTY"] = "표시된 준비 단계가 없습니다. 등록된 퀘스트를 보려면 %s 모드로 전환하세요.", ["QUEST_PAYMENT"] = "명시된 지불액: %s", ["MONEY_COPPER"] = "동화 %.0f", ["QUEST_PAYMENT_NOTICE"] = "이 비용으로 퀘스트 수락 가능 여부가 확인되지는 않습니다.", ["SEARCH_QUEST_MATCH"] = "퀘스트: %s", ["STORY_SOURCE_QUESTS"] = "이야기에 나열된 퀘스트: %d", ["OBJECTIVE_OBJECTS"] = "추가 퀘스트 목표", ["OBJECTIVE_OBJECTS_NOTICE"] = "아래 항목은 퀘스트 목표이며, 확인된 수락 조건이나 현재 진행 상황이 아닙니다.", ["OPEN_QUEST_LOG"] = "퀘스트 목록에서 열기", ["QUEST_TEXT"] = "퀘스트 내용", ["ITEM_DROP_LOCATIONS"] = "알려진 아이템 획득 위치 — 획득 가능 여부 미확인", ["ITEM_ACQUISITION"] = "퀘스트 시작 아이템 획득처", ["ITEM_ACQUISITION_UNKNOWN"] = "아이템 획득처가 아직 확인되지 않았습니다.", ["PROVIDED_ITEMS"] = "퀘스트 제공 아이템", ["PROVIDED_ITEMS_NOTICE"] = "제공 아이템은 퀘스트 중 사용되거나 소모될 수 있습니다. 현재 소지 수량은 별도로 표시됩니다.", ["OBJECTIVE_KILLS"] = "기록된 처치 목표", ["OBJECTIVE_KILLS_NOTICE"] = "기록된 대상은 퀘스트 목표이며, 확인된 수락 조건이나 현재 진행 상황이 아닙니다.", ["GIVER_REFERENCE_PORTRAIT"] = "퀘스트 제공자: %s", ["QUEST_FACTIONS"] = "진영: %s", ["PREPARATION_FOR"] = "준비 대상", ["PREPARATION_FOR_NOTICE"] = "현재 준비 계획의 대상입니다. 다른 방법이 있을 수 있습니다.", ["LANGUAGE_AUTO"] = "자동 (게임 언어)", ["GUIDE_DISTANCE"] = "%.0f야드", ["BRANCH_INSPECT"] = "퀘스트 보기", ["OVERVIEW_PICK"] = "목록에서 퀘스트를 선택하면 상세 정보와 준비 단계를 볼 수 있습니다.", ["OVERVIEW_REVIEWED"] = "퀘스트 목록을 검토했지만 개별 조건은 아직 확인되지 않았을 수 있습니다.", ["FACTION_Alliance"] = "얼라이언스", ["FACTION_Horde"] = "호드", ["FACTION_Neutral"] = "중립", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — 수량 미확인", ["MINIMAP_OPEN"] = "왼쪽 클릭: Dungeon Pro 열기 또는 닫기.", ["MINIMAP_DRAG"] = "아이콘을 끌어 미니맵 주위로 이동하세요.", ["OBJECTIVE_ITEMS"] = "명시된 아이템 목표", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "나열된 아이템은 퀘스트 목표이며, 확인된 수락 조건이나 현재 진행 상황이 아닙니다.",  ["QUEST_MIN_LEVEL"] = "최소 레벨: %.0f", ["QUEST_CLASSES"] = "직업: %s", ["QUEST_RACES"] = "종족: %s", ["RACE_ID"] = "종족 #%.0f",  ["QUEST_LOG_CAPACITY"] = "퀘스트 목록: %.0f/%.0f", ["ITEM_CARRIED"] = "소지: %.0f", ["DUNGEON_WING_lower"] = "%s — 하층", ["DUNGEON_WING_upper"] = "%s — 상층", ["REWARD_PREVIEW"] = "퀘스트 보상 미리 보기", ["UNKNOWN_REQUIREMENTS"] = "퀘스트 목록에 없음 — 조건 미확인", ["CONTAINER_SOURCE"] = "알려진 아이템 보관함 — 이용 가능 여부 미확인", ["REPORTED_POSITIONS"] = "%s — 보고된 위치 (%d)", ["REPORTED_NOTICE"] = "이 지점들은 이동이나 퀘스트 단계를 반영할 수 있습니다. NPC 또는 오브젝트의 현재 위치를 확정하지 않습니다.", ["REPORTED_VISIT"] = "이 보고된 위치 방문", ["COMPLETED_BEFORE"] = "이전에 완료함", ["DETAIL_BACK"] = "뒤로", ["REQUIREMENT_GROUPS"] = "알려진 선행 조건 그룹", ["REQUIREMENT_NOTICE"] = "나열된 모든 그룹이 필요하며 각 그룹에서 퀘스트 하나면 됩니다. 알려지지 않은 추가 조건이 있을 수 있습니다.", ["REQUIREMENT_GROUP"] = "조건 %d", ["REQUIREMENT_ACTIVE"] = "퀘스트 하나를 수락하거나 완료하세요.", ["REQUIREMENT_COMPLETE"] = "퀘스트 하나를 완료하세요.", ["CATALOG_LEVELS"] = "%d–%d 레벨", ["CATALOG_QUESTS"] = "목록의 퀘스트: %d개", ["OBJECTIVE_DIALOGUE"] = "열린 퀘스트 대화의 목표", ["OBJECTIVE_PROGRESS"] = "게임에서 제공한 목표", ["REWARD_DIALOGUE"] = "열린 퀘스트 대화의 보상", ["REWARD_HIDDEN"] = "클라이언트가 이 퀘스트의 보상을 표시하지 않습니다.", ["REWARD_XP"] = "경험치: %d",  ["OFFERED_NOW"] = "현재 NPC 대화에서 제공되는 퀘스트입니다.", ["ITEM_CLASSES"] = "아이템 직업: %s", ["ITEM_MIN_LEVEL"] = "아이템 요구 레벨: %d.", ["ITEM_REQUIREMENTS_NOTICE"] = "아이템 요구 조건입니다. 퀘스트 수락 가능 여부는 별도로 확인합니다.", ["POSSIBLE_TURNINS"] = "가능한 완료 지점 — 이용 가능 여부 미확인", ["STORY_GROUP"] = "이야기 그룹 %d", ["STORY_GROUP_NOTICE"] = "출처에서 이 퀘스트들을 함께 표시합니다. 선행 조건이나 캐릭터가 수락할 수 있는 퀘스트를 확정하지는 않습니다.", ["START_ALTERNATIVES"] = "가능한 시작 지점 — 퀘스트 가능 여부 미확인", ["ITEM_STARTER"] = "퀘스트 시작 아이템: %s", ["ITEM_DROP_SOURCE"] = "%s에게서 획득: %s.", ["QUEST_PORTRAIT"] = "퀘스트 초상화", ["REPEATABLE"] = "반복 가능한 퀘스트", ["MATERIAL_QUESTS"] = "필요한 재료를 주는 퀘스트", ["MATERIAL_ITEM"] = "아이템 #%d", ["MATERIAL_NOTICE"] = "완료에 필요한 재료의 출처이며, 수락에 필요한 선행 퀘스트로 확인된 것은 아닙니다. 퀘스트를 완료했어도 재료를 아직 보유하고 있다는 뜻은 아닙니다.", ["SEARCH_HELP"] = "던전, 목록의 퀘스트, 기록된 NPC와 장소를 검색하거나 퀘스트 ID를 입력하세요. 대소문자는 구분하지 않지만 악센트와 철자는 일치해야 합니다.", ["NO_DUNGEONS"] = "검색어와 선택한 필터에 맞는 던전이 없습니다.", ["REWARD_ITEMS"] = "아이템 보상", ["REWARD_CHOICES"] = "아이템 하나 선택", ["REWARD_ITEM"] = "%s ×%d", ["REWARD_NO_ITEMS"] = "아이템 보상이 없습니다.", ["REWARD_UNAVAILABLE"] = "이 퀘스트의 보상 정보를 확인할 수 없습니다.", ["REWARD_MONEY"] = "골드", ["REWARD_MONEY_UNKNOWN"] = "금전 보상을 표시할 수 없습니다.", ["BRANCH_GROUP"] = "조건 %d: 하나 선택", ["BRANCH_AUTO"] = "자동", ["BRANCH_SELECTED"] = "%s (선택됨)", ["VISIT_GIVER"] = "퀘스트 제공자 방문", ["GIVER_MAP"] = "지도에서 제공자 보기", ["LOCATION_ONLY"] = "위치 안내만 제공합니다. 퀘스트 수락 가능 여부는 확인되지 않았습니다.", ["NO_CHARACTER_QUESTS"] = "이 캐릭터의 알려진 퀘스트가 없습니다. 다른 퀘스트를 보려면 %s로 전환하세요.", ["MY_CHARACTER"] = "내 캐릭터", ["ALL_CHARACTERS"] = "모든 캐릭터", ["PREP_unavailable"] = "이 캐릭터는 수행 불가", ["REASON_requirements"] = "필요한 퀘스트 단계가 아직 끝나지 않았습니다.", ["REASON_requirementsUnknown"] = "퀘스트 조건이 아직 완전히 확인되지 않았습니다.", ["REASON_character"] = "퀘스트 기록 또는 캐릭터 제한을 확인할 수 없습니다.", ["REASON_level"] = "필요 레벨: %d.", ["REASON_level_current"] = "필요 레벨: %d, 현재 레벨: %d.", ["REASON_levelUnknown"] = "캐릭터 레벨을 확인할 수 없습니다.", ["REASON_missing"] = "목록에 이 퀘스트 정보가 없습니다.", ["REASON_cycle"] = "퀘스트 선행 조건이 순환하므로 수락 가능 여부를 판단할 수 없습니다.", ["REASON_faction"] = "이 퀘스트의 진영 조건을 충족하지 않습니다.", ["REASON_class"] = "이 퀘스트의 직업 조건을 충족하지 않습니다.", ["REASON_race"] = "이 퀘스트의 종족 조건을 충족하지 않습니다.", ["PREP_outside"] = "입장 전에 수락", ["PREP_inside"] = "던전 안에서 수락", ["PREP_level"] = "레벨 조건", ["PREP_progress"] = "수행 또는 완료 보고", ["PREP_uncertain"] = "아직 확인되지 않은 조건", ["ACTIVE"] = "퀘스트 목록에 있음", ["ALL"] = "모든 레벨", ["AVAILABLE"] = "수락 가능", ["CHAIN"] = "연속 퀘스트", ["CLEAR"] = "안내 해제", ["COMPLETED"] = "완료", ["COPY"] = "링크를 선택하고 Ctrl+C를 누르세요.", ["DEVELOPMENT"] = "개발 버전 — 던전 데이터가 불완전합니다", ["EMPTY"] = "이 던전의 퀘스트 데이터가 아직 추가되지 않았습니다.", ["ENDING"] = "완료 보고 위치", ["GUIDE"] = "방향 안내", ["LOCKED"] = "준비 필요", ["MAP"] = "지도에 표시", ["NEXT"] = "다음 단계", ["NOT_PREPARED"] = "준비할 내용이 남아 있습니다", ["NO_POSITION"] = "위치를 확인할 수 없거나 다른 대륙에 있습니다", ["NO_TEXT"] = "원래 퀘스트 내용을 사용할 수 없습니다. 퀘스트 제안 창을 열어 내용을 저장하세요.", ["ONLY_EN_RU"] = "언어", ["PARTIAL"] = "퀘스트 목록의 완전성을 확인 중입니다", ["PICK"] = "던전을 선택한 후 퀘스트를 선택하세요.", ["PREPARED"] = "알려진 퀘스트 준비 완료", ["QUESTS"] = "던전 퀘스트", ["RANGE"] = "내 레벨", ["READY"] = "완료 보고 가능", ["SEARCH"] = "던전, 퀘스트, NPC", ["SOURCE"] = "Wowhead 링크", ["START"] = "시작 위치", ["STORY"] = "이야기 순서 (선행 조건 확인 중)", ["SUBTITLE"] = "입장 전에 준비하세요", ["SUMMARY"] = "수락: %d   완료: %d   준비 필요: %d   정보 없음: %d", ["TITLE"] = "Dungeon Pro", ["UNAVAILABLE"] = "이 캐릭터는 수행 불가", ["UNKNOWN"] = "정보 부족", ["UNKNOWN_PLACE"] = "위치 정보 없음", ["UNSUPPORTED"] = "이 버전은 WoW Forever만 지원합니다.", ["complete"] = "퀘스트 수행", ["inside"] = "던전 안에서 수락", ["level"] = "필요 레벨 달성", ["pickup"] = "수락", ["turnin"] = "완료 보고" }
addon.locales.zhCN = { ["SEARCH_OBJECTIVE_MATCH"] = "任务目标：%s", ["SEARCH_NPC_MATCH"] = "NPC：%s", ["SEARCH_PLACE_MATCH"] = "地点：%s", ["OBJECTIVE_ITEM_SOURCES"] = "任务物品获取地点", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "已知物品来源；尚未确认当前是否可以获取。", ["LANGUAGE_AUTO_SHORT"] = "自动", ["QUEST_LEVEL"] = "任务等级：%.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "交付任务：%s", ["DIALOGUE_PROGRESS_TEXT"] = "当前任务对话", ["DIALOGUE_TURNIN_TEXT"] = "当前交付任务对话", ["GAME_WAYPOINT"] = "游戏路标", ["GAME_WAYPOINT_NOTICE"] = "路标可能指向沿途路线、入口或任务交付地点。", ["GAME_WAYPOINT_FOLLOW"] = "跟随游戏路标", ["QUEST_LOG_PAYMENT"] = "任务日志所列费用：%s", ["PREPARATION_EMPTY"] = "当前没有显示准备步骤。切换到“%s”查看已列出的任务。", ["QUEST_PAYMENT"] = "资料所列费用：%s", ["MONEY_COPPER"] = "%.0f 铜币", ["QUEST_PAYMENT_NOTICE"] = "这项费用不能确认任务是否可接。", ["SEARCH_QUEST_MATCH"] = "任务：%s", ["STORY_SOURCE_QUESTS"] = "剧情列表中的任务：%d", ["OBJECTIVE_OBJECTS"] = "其他已列出的目标", ["OBJECTIVE_OBJECTS_NOTICE"] = "以下内容是任务目标，不代表已确认的接取条件或当前进度。", ["OPEN_QUEST_LOG"] = "在任务日志中打开", ["QUEST_TEXT"] = "任务文本", ["ITEM_DROP_LOCATIONS"] = "已知物品掉落位置 — 可获取性未确认", ["ITEM_ACQUISITION"] = "获取任务起始物品", ["ITEM_ACQUISITION_UNKNOWN"] = "尚未核实此物品的获取来源。", ["PROVIDED_ITEMS"] = "任务提供的物品", ["PROVIDED_ITEMS_NOTICE"] = "提供的物品可能在任务过程中使用或消耗。当前携带数量单独显示。", ["OBJECTIVE_KILLS"] = "已列出的击杀目标", ["OBJECTIVE_KILLS_NOTICE"] = "列出的目标是任务目标，不代表已确认的接取条件或当前进度。", ["GIVER_REFERENCE_PORTRAIT"] = "任务给予者：%s", ["QUEST_FACTIONS"] = "阵营：%s", ["PREPARATION_FOR"] = "准备目标", ["PREPARATION_FOR_NOTICE"] = "当前准备计划中的目标；可能还有其他途径。", ["LANGUAGE_AUTO"] = "自动（游戏语言）", ["GUIDE_DISTANCE"] = "%.0f码", ["BRANCH_INSPECT"] = "查看任务", ["OVERVIEW_PICK"] = "选择列表中的任务，查看详情和准备步骤。", ["OVERVIEW_REVIEWED"] = "任务列表已核查；个别条件可能仍未确认。", ["FACTION_Alliance"] = "联盟", ["FACTION_Horde"] = "部落", ["FACTION_Neutral"] = "中立", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — 数量未核实", ["MINIMAP_OPEN"] = "左键点击：打开或关闭 Dungeon Pro。", ["MINIMAP_DRAG"] = "拖动图标可沿小地图移动。", ["OBJECTIVE_ITEMS"] = "列出的物品目标", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "列出的物品是任务目标，不代表已确认的接取条件或当前进度。",  ["QUEST_MIN_LEVEL"] = "最低等级：%.0f", ["QUEST_CLASSES"] = "职业：%s", ["QUEST_RACES"] = "种族：%s", ["RACE_ID"] = "种族 #%.0f",  ["QUEST_LOG_CAPACITY"] = "任务日志：%.0f/%.0f", ["ITEM_CARRIED"] = "随身携带：%.0f", ["DUNGEON_WING_lower"] = "%s — 下层", ["DUNGEON_WING_upper"] = "%s — 上层", ["REWARD_PREVIEW"] = "任务奖励预览", ["UNKNOWN_REQUIREMENTS"] = "不在任务日志中 — 条件尚未核实", ["CONTAINER_SOURCE"] = "已知物品容器——可用性未确认", ["REPORTED_POSITIONS"] = "%s — 已记录位置（%d）", ["REPORTED_NOTICE"] = "这些位置可能反映移动或任务阶段，并不代表NPC或物体当前一定在此。", ["REPORTED_VISIT"] = "前往此记录位置", ["COMPLETED_BEFORE"] = "曾经完成", ["DETAIL_BACK"] = "返回", ["REQUIREMENT_GROUPS"] = "已知前置条件组", ["REQUIREMENT_NOTICE"] = "每个列出的条件组都必须满足，每组只需一个任务。可能还有未知的额外条件。", ["REQUIREMENT_GROUP"] = "条件 %d", ["REQUIREMENT_ACTIVE"] = "接受或完成一个任务。", ["REQUIREMENT_COMPLETE"] = "完成一个任务。", ["CATALOG_LEVELS"] = "等级 %d–%d", ["CATALOG_QUESTS"] = "已列出的任务：%d", ["OBJECTIVE_DIALOGUE"] = "当前任务对话中的目标", ["OBJECTIVE_PROGRESS"] = "游戏提供的目标", ["REWARD_DIALOGUE"] = "当前任务对话中的奖励", ["REWARD_HIDDEN"] = "客户端未显示此任务的奖励。", ["REWARD_XP"] = "经验值：%d",  ["OFFERED_NOW"] = "当前NPC对话中提供的任务。", ["ITEM_CLASSES"] = "物品职业：%s", ["ITEM_MIN_LEVEL"] = "物品需要等级%d。", ["ITEM_REQUIREMENTS_NOTICE"] = "仅为物品要求。任务可接取状态另行检查。", ["POSSIBLE_TURNINS"] = "可能的交付地点 — 可用状态尚未确认", ["STORY_GROUP"] = "剧情组 %d", ["STORY_GROUP_NOTICE"] = "来源将这些任务列在同一组中。这不代表已确认前置条件或你的角色可以接取哪些任务。", ["START_ALTERNATIVES"] = "可能的起始地点 — 可接取状态尚未确认", ["ITEM_STARTER"] = "任务起始物品：%s", ["ITEM_DROP_SOURCE"] = "由%s掉落，地点：%s。", ["QUEST_PORTRAIT"] = "任务肖像", ["REPEATABLE"] = "可重复任务", ["MATERIAL_QUESTS"] = "所需材料的来源任务", ["MATERIAL_ITEM"] = "物品#%d", ["MATERIAL_NOTICE"] = "这些任务提供完成所需的材料，并非已确认的接取前置条件。完成来源任务不代表你仍持有相应物品。", ["SEARCH_HELP"] = "搜索地下城、列出的任务、已记录的NPC和地点，或输入任务ID。不区分字母大小写，重音符号和拼写仍须一致。", ["NO_DUNGEONS"] = "没有符合当前搜索和筛选条件的地下城。", ["REWARD_ITEMS"] = "物品奖励", ["REWARD_CHOICES"] = "选择一件物品", ["REWARD_ITEM"] = "%s ×%d", ["REWARD_NO_ITEMS"] = "无物品奖励。", ["REWARD_UNAVAILABLE"] = "无法获取此任务的奖励信息。", ["REWARD_MONEY"] = "金钱", ["REWARD_MONEY_UNKNOWN"] = "无法显示金钱奖励。", ["BRANCH_GROUP"] = "条件%d：选择一项", ["BRANCH_AUTO"] = "自动", ["BRANCH_SELECTED"] = "%s（已选择）", ["VISIT_GIVER"] = "前往任务发布者处", ["GIVER_MAP"] = "地图上的任务发布者", ["LOCATION_ONLY"] = "仅提供位置；尚未确认任务是否可接取。", ["NO_CHARACTER_QUESTS"] = "暂无此角色的已知任务。切换至“%s”查看其他任务。", ["MY_CHARACTER"] = "我的角色", ["ALL_CHARACTERS"] = "所有角色", ["PREP_unavailable"] = "此角色无法接取", ["REASON_requirements"] = "所需的任务步骤尚未完成。", ["REASON_requirementsUnknown"] = "任务条件尚未全部核实。", ["REASON_character"] = "无法检查任务历史或角色限制。", ["REASON_level"] = "需要等级%d。", ["REASON_level_current"] = "需要等级%d；当前等级：%d。", ["REASON_levelUnknown"] = "无法检查你的等级。", ["REASON_missing"] = "目录中缺少此任务的信息。", ["REASON_cycle"] = "任务依赖存在循环，无法确定是否可接取。", ["REASON_faction"] = "你的阵营不符合此任务的要求。", ["REASON_class"] = "你的职业不符合此任务的要求。", ["REASON_race"] = "你的种族不符合此任务的要求。", ["PREP_outside"] = "进入前接取", ["PREP_inside"] = "在地下城内接取", ["PREP_level"] = "等级要求", ["PREP_progress"] = "完成或交付", ["PREP_uncertain"] = "条件尚不明确", ["ACTIVE"] = "任务日志中", ["ALL"] = "所有等级", ["AVAILABLE"] = "可以接取", ["CHAIN"] = "任务链", ["CLEAR"] = "清除指引", ["COMPLETED"] = "已完成", ["COPY"] = "选中链接并按Ctrl+C。", ["DEVELOPMENT"] = "开发版本 — 地下城数据尚不完整", ["EMPTY"] = "此地下城的任务数据尚未添加。", ["ENDING"] = "交付地点", ["GUIDE"] = "指示方向", ["LOCKED"] = "需要准备", ["MAP"] = "在地图上显示", ["NEXT"] = "下一步", ["NOT_PREPARED"] = "仍需准备", ["NO_POSITION"] = "无法获取位置或目标在另一大陆", ["NO_TEXT"] = "原始任务文本不可用。打开任务接受对话以保存文本。", ["ONLY_EN_RU"] = "语言", ["PARTIAL"] = "任务列表完整性仍在核查中", ["PICK"] = "请选择地下城和任务。", ["PREPARED"] = "已知任务已准备就绪", ["QUESTS"] = "地下城任务", ["RANGE"] = "我的等级", ["READY"] = "可以交付", ["SEARCH"] = "地下城、任务或NPC", ["SOURCE"] = "Wowhead链接", ["START"] = "接取地点", ["STORY"] = "剧情顺序（前置条件核查中）", ["SUBTITLE"] = "进入前做好准备", ["SUMMARY"] = "已接：%d   已完成：%d   需准备：%d   未知：%d", ["TITLE"] = "Dungeon Pro", ["UNAVAILABLE"] = "此角色无法接取", ["UNKNOWN"] = "信息不足", ["UNKNOWN_PLACE"] = "地点暂时未知", ["UNSUPPORTED"] = "此版本仅支持WoW Forever。", ["complete"] = "完成任务", ["inside"] = "在地下城内接取", ["level"] = "达到等级", ["pickup"] = "接取", ["turnin"] = "交付" }
addon.locales.zhTW = { ["SEARCH_OBJECTIVE_MATCH"] = "任務目標：%s", ["SEARCH_NPC_MATCH"] = "NPC：%s", ["SEARCH_PLACE_MATCH"] = "地點：%s", ["OBJECTIVE_ITEM_SOURCES"] = "任務物品取得地點", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "已知物品來源；尚未確認目前是否可以取得。", ["LANGUAGE_AUTO_SHORT"] = "自動", ["QUEST_LEVEL"] = "任務等級：%.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "繳交任務：%s", ["DIALOGUE_PROGRESS_TEXT"] = "目前任務對話", ["DIALOGUE_TURNIN_TEXT"] = "目前繳交任務對話", ["GAME_WAYPOINT"] = "遊戲路標", ["GAME_WAYPOINT_NOTICE"] = "路標可能指向沿途路線、入口或任務交付地點。", ["GAME_WAYPOINT_FOLLOW"] = "跟隨遊戲路標", ["QUEST_LOG_PAYMENT"] = "任務日誌所列費用：%s", ["PREPARATION_EMPTY"] = "目前沒有顯示準備步驟。切換至「%s」查看已列出的任務。", ["QUEST_PAYMENT"] = "資料所列費用：%s", ["MONEY_COPPER"] = "%.0f 銅幣", ["QUEST_PAYMENT_NOTICE"] = "這項費用無法確認任務是否可接。", ["SEARCH_QUEST_MATCH"] = "任務：%s", ["STORY_SOURCE_QUESTS"] = "劇情清單中的任務：%d", ["OBJECTIVE_OBJECTS"] = "其他已列出的目標", ["OBJECTIVE_OBJECTS_NOTICE"] = "以下內容是任務目標，不代表已確認的接取條件或目前進度。", ["OPEN_QUEST_LOG"] = "在任務日誌中開啟", ["QUEST_TEXT"] = "任務文字", ["ITEM_DROP_LOCATIONS"] = "已知物品掉落位置 — 取得狀況未確認", ["ITEM_ACQUISITION"] = "取得任務起始物品", ["ITEM_ACQUISITION_UNKNOWN"] = "尚未確認此物品的取得來源。", ["PROVIDED_ITEMS"] = "任務提供的物品", ["PROVIDED_ITEMS_NOTICE"] = "提供的物品可能在任務過程中使用或消耗。目前攜帶數量會單獨顯示。", ["OBJECTIVE_KILLS"] = "已列出的擊殺目標", ["OBJECTIVE_KILLS_NOTICE"] = "列出的目標是任務目標，不代表已確認的接取條件或目前進度。", ["GIVER_REFERENCE_PORTRAIT"] = "任務給予者：%s", ["QUEST_FACTIONS"] = "陣營：%s", ["PREPARATION_FOR"] = "準備目標", ["PREPARATION_FOR_NOTICE"] = "目前準備計畫中的目標；可能還有其他途徑。", ["LANGUAGE_AUTO"] = "自動（遊戲語言）", ["GUIDE_DISTANCE"] = "%.0f碼", ["BRANCH_INSPECT"] = "查看任務", ["OVERVIEW_PICK"] = "選擇清單中的任務，查看詳情和準備步驟。", ["OVERVIEW_REVIEWED"] = "任務清單已核查；個別條件可能仍未確認。", ["FACTION_Alliance"] = "聯盟", ["FACTION_Horde"] = "部落", ["FACTION_Neutral"] = "中立", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — 數量未核實", ["MINIMAP_OPEN"] = "左鍵點擊：開啟或關閉 Dungeon Pro。", ["MINIMAP_DRAG"] = "拖曳圖示可沿小地圖移動。", ["OBJECTIVE_ITEMS"] = "列出的物品目標", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "列出的物品是任務目標，不代表已確認的接取條件或目前進度。",  ["QUEST_MIN_LEVEL"] = "最低等級：%.0f", ["QUEST_CLASSES"] = "職業：%s", ["QUEST_RACES"] = "種族：%s", ["RACE_ID"] = "種族 #%.0f",  ["QUEST_LOG_CAPACITY"] = "任務日誌：%.0f/%.0f", ["ITEM_CARRIED"] = "隨身攜帶：%.0f", ["DUNGEON_WING_lower"] = "%s — 下層", ["DUNGEON_WING_upper"] = "%s — 上層", ["REWARD_PREVIEW"] = "任務獎勵預覽", ["UNKNOWN_REQUIREMENTS"] = "不在任務日誌中 — 條件尚未核實", ["CONTAINER_SOURCE"] = "已知物品容器——可用性未確認", ["REPORTED_POSITIONS"] = "%s — 已回報位置（%d）", ["REPORTED_NOTICE"] = "這些位置可能反映移動或任務階段，並不代表NPC或物件目前一定在此。", ["REPORTED_VISIT"] = "前往此回報位置", ["COMPLETED_BEFORE"] = "曾經完成", ["DETAIL_BACK"] = "返回", ["REQUIREMENT_GROUPS"] = "已知前置條件組", ["REQUIREMENT_NOTICE"] = "每個列出的條件組都必須滿足，每組只需一個任務。可能還有未知的額外條件。", ["REQUIREMENT_GROUP"] = "條件 %d", ["REQUIREMENT_ACTIVE"] = "接受或完成一個任務。", ["REQUIREMENT_COMPLETE"] = "完成一個任務。", ["CATALOG_LEVELS"] = "等級 %d–%d", ["CATALOG_QUESTS"] = "已列出的任務：%d", ["OBJECTIVE_DIALOGUE"] = "目前任務對話中的目標", ["OBJECTIVE_PROGRESS"] = "遊戲提供的目標", ["REWARD_DIALOGUE"] = "目前任務對話中的獎勵", ["REWARD_HIDDEN"] = "用戶端未顯示此任務的獎勵。", ["REWARD_XP"] = "經驗值：%d",  ["OFFERED_NOW"] = "目前NPC對話中提供的任務。", ["ITEM_CLASSES"] = "物品職業：%s", ["ITEM_MIN_LEVEL"] = "物品需要等級%d。", ["ITEM_REQUIREMENTS_NOTICE"] = "僅為物品要求。任務可接受狀態另行檢查。", ["POSSIBLE_TURNINS"] = "可能的交付地點 — 可用狀態尚未確認", ["STORY_GROUP"] = "劇情組 %d", ["STORY_GROUP_NOTICE"] = "來源將這些任務列在同一組中。這不代表已確認前置條件或你的角色可以接取哪些任務。", ["START_ALTERNATIVES"] = "可能的起始地點 — 可接取狀態尚未確認", ["ITEM_STARTER"] = "任務起始物品：%s", ["ITEM_DROP_SOURCE"] = "由%s掉落，地點：%s。", ["QUEST_PORTRAIT"] = "任務肖像", ["REPEATABLE"] = "可重複任務", ["MATERIAL_QUESTS"] = "所需材料的來源任務", ["MATERIAL_ITEM"] = "物品#%d", ["MATERIAL_NOTICE"] = "這些任務提供完成所需的材料，並非已確認的接受前置條件。完成來源任務不代表你仍持有相應物品。", ["SEARCH_HELP"] = "搜尋地城、列出的任務、已記錄的NPC和地點，或輸入任務ID。不區分字母大小寫，重音符號和拼寫仍須一致。", ["NO_DUNGEONS"] = "沒有符合目前搜尋和篩選條件的地城。", ["REWARD_ITEMS"] = "物品獎勵", ["REWARD_CHOICES"] = "選擇一件物品", ["REWARD_ITEM"] = "%s ×%d", ["REWARD_NO_ITEMS"] = "無物品獎勵。", ["REWARD_UNAVAILABLE"] = "無法取得此任務的獎勵資訊。", ["REWARD_MONEY"] = "金錢", ["REWARD_MONEY_UNKNOWN"] = "無法顯示金錢獎勵。", ["BRANCH_GROUP"] = "條件%d：選擇一項", ["BRANCH_AUTO"] = "自動", ["BRANCH_SELECTED"] = "%s（已選取）", ["VISIT_GIVER"] = "前往任務提供者處", ["GIVER_MAP"] = "地圖上的任務提供者", ["LOCATION_ONLY"] = "僅提供位置；尚未確認任務是否可以接受。", ["NO_CHARACTER_QUESTS"] = "暫無此角色的已知任務。切換至「%s」查看其他任務。", ["MY_CHARACTER"] = "我的角色", ["ALL_CHARACTERS"] = "所有角色", ["PREP_unavailable"] = "此角色無法接受", ["REASON_requirements"] = "所需的任務步驟尚未完成。", ["REASON_requirementsUnknown"] = "任務條件尚未全部核實。", ["REASON_character"] = "無法檢查任務歷史或角色限制。", ["REASON_level"] = "需要等級%d。", ["REASON_level_current"] = "需要等級%d；目前等級：%d。", ["REASON_levelUnknown"] = "無法檢查你的等級。", ["REASON_missing"] = "目錄中缺少此任務的資訊。", ["REASON_cycle"] = "任務依賴存在循環，無法確定是否可以接受。", ["REASON_faction"] = "你的陣營不符合此任務的要求。", ["REASON_class"] = "你的職業不符合此任務的要求。", ["REASON_race"] = "你的種族不符合此任務的要求。", ["PREP_outside"] = "進入前接受", ["PREP_inside"] = "在地城內接受", ["PREP_level"] = "等級要求", ["PREP_progress"] = "完成或交付", ["PREP_uncertain"] = "條件尚不明確", ["ACTIVE"] = "任務日誌中", ["ALL"] = "所有等級", ["AVAILABLE"] = "可以接受", ["CHAIN"] = "任務鏈", ["CLEAR"] = "清除指引", ["COMPLETED"] = "已完成", ["COPY"] = "選取連結並按Ctrl+C。", ["DEVELOPMENT"] = "開發版本 — 地城資料尚不完整", ["EMPTY"] = "此地城的任務資料尚未加入。", ["ENDING"] = "交付地點", ["GUIDE"] = "指示方向", ["LOCKED"] = "需要準備", ["MAP"] = "在地圖上顯示", ["NEXT"] = "下一步", ["NOT_PREPARED"] = "仍需準備", ["NO_POSITION"] = "無法取得位置或目標在另一大陸", ["NO_TEXT"] = "無法取得原始任務文字。開啟任務接受對話以儲存文字。", ["ONLY_EN_RU"] = "語言", ["PARTIAL"] = "任務清單完整性仍在核查中", ["PICK"] = "請選擇地城和任務。", ["PREPARED"] = "已知任務已準備就緒", ["QUESTS"] = "地城任務", ["RANGE"] = "我的等級", ["READY"] = "可以交付", ["SEARCH"] = "地城、任務或NPC", ["SOURCE"] = "Wowhead連結", ["START"] = "接受地點", ["STORY"] = "劇情順序（前置條件核查中）", ["SUBTITLE"] = "進入前做好準備", ["SUMMARY"] = "已接：%d   已完成：%d   需準備：%d   未知：%d", ["TITLE"] = "Dungeon Pro", ["UNAVAILABLE"] = "此角色無法接受", ["UNKNOWN"] = "資訊不足", ["UNKNOWN_PLACE"] = "地點暫時未知", ["UNSUPPORTED"] = "此版本僅支援WoW Forever。", ["complete"] = "完成任務", ["inside"] = "在地城內接受", ["level"] = "達到等級", ["pickup"] = "接受", ["turnin"] = "交付" }

addon.locales.deDE.DETAIL_MORE, addon.locales.deDE.DETAIL_LESS = "Weitere Details", "Details ausblenden"
addon.locales.deDE.DETAIL_CHAIN = "Bekannte Questreihe"
addon.locales.frFR.DETAIL_MORE, addon.locales.frFR.DETAIL_LESS = "Plus de détails", "Masquer les détails"
addon.locales.frFR.DETAIL_CHAIN = "Suite de quêtes connue"
addon.locales.esES.DETAIL_MORE, addon.locales.esES.DETAIL_LESS = "Más detalles", "Ocultar detalles"
addon.locales.esES.DETAIL_CHAIN = "Cadena de misiones conocida"
addon.locales.itIT.DETAIL_MORE, addon.locales.itIT.DETAIL_LESS = "Altri dettagli", "Nascondi dettagli"
addon.locales.itIT.DETAIL_CHAIN = "Serie di missioni conosciuta"
addon.locales.ptBR.DETAIL_MORE, addon.locales.ptBR.DETAIL_LESS = "Mais detalhes", "Ocultar detalhes"
addon.locales.ptBR.DETAIL_CHAIN = "Cadeia de missões conhecida"
addon.locales.koKR.DETAIL_MORE, addon.locales.koKR.DETAIL_LESS = "자세히 보기", "세부 정보 숨기기"
addon.locales.koKR.DETAIL_CHAIN = "알려진 연계 퀘스트"
addon.locales.zhCN.DETAIL_MORE, addon.locales.zhCN.DETAIL_LESS = "更多详情", "隐藏详情"
addon.locales.zhCN.DETAIL_CHAIN = "已知任务链"
addon.locales.zhTW.DETAIL_MORE, addon.locales.zhTW.DETAIL_LESS = "更多詳情", "隱藏詳情"
addon.locales.zhTW.DETAIL_CHAIN = "已知任務鏈"
addon.locales.deDE.DUNGEON_ENTRANCE, addon.locales.deDE.STEP_MAP, addon.locales.deDE.STEP_GUIDE = "Dungeon-Eingang", "Aktueller Schritt auf der Karte", "Zum aktuellen Schritt führen"
addon.locales.frFR.DUNGEON_ENTRANCE, addon.locales.frFR.STEP_MAP, addon.locales.frFR.STEP_GUIDE = "Entrée du donjon", "Étape actuelle sur la carte", "Guider vers l'étape actuelle"
addon.locales.esES.DUNGEON_ENTRANCE, addon.locales.esES.STEP_MAP, addon.locales.esES.STEP_GUIDE = "Entrada de la mazmorra", "Paso actual en el mapa", "Guiar al paso actual"
addon.locales.itIT.DUNGEON_ENTRANCE, addon.locales.itIT.STEP_MAP, addon.locales.itIT.STEP_GUIDE = "Ingresso della spedizione", "Passaggio attuale sulla mappa", "Guida al passaggio attuale"
addon.locales.ptBR.DUNGEON_ENTRANCE, addon.locales.ptBR.STEP_MAP, addon.locales.ptBR.STEP_GUIDE = "Entrada da masmorra", "Etapa atual no mapa", "Guiar até a etapa atual"
addon.locales.koKR.DUNGEON_ENTRANCE, addon.locales.koKR.STEP_MAP, addon.locales.koKR.STEP_GUIDE = "던전 입구", "현재 단계 지도", "현재 단계로 안내"
addon.locales.zhCN.DUNGEON_ENTRANCE, addon.locales.zhCN.STEP_MAP, addon.locales.zhCN.STEP_GUIDE = "地下城入口", "在地图上查看当前步骤", "指引前往当前步骤"
addon.locales.zhTW.DUNGEON_ENTRANCE, addon.locales.zhTW.STEP_MAP, addon.locales.zhTW.STEP_GUIDE = "地城入口", "在地圖上查看目前步驟", "指引前往目前步驟"
addon.locales.deDE.DUNGEON_ENTRANCE_UNKNOWN = "Der Eingangsort wurde noch nicht bestätigt."
addon.locales.frFR.DUNGEON_ENTRANCE_UNKNOWN = "L'emplacement de l'entrée n'a pas encore été vérifié."
addon.locales.esES.DUNGEON_ENTRANCE_UNKNOWN = "La ubicación de la entrada aún no se ha verificado."
addon.locales.itIT.DUNGEON_ENTRANCE_UNKNOWN = "La posizione dell'ingresso non è ancora stata verificata."
addon.locales.ptBR.DUNGEON_ENTRANCE_UNKNOWN = "A localização da entrada ainda não foi verificada."
addon.locales.koKR.DUNGEON_ENTRANCE_UNKNOWN = "입구 위치가 아직 확인되지 않았습니다."
addon.locales.zhCN.DUNGEON_ENTRANCE_UNKNOWN = "入口位置尚未确认。"
addon.locales.zhTW.DUNGEON_ENTRANCE_UNKNOWN = "入口位置尚未確認。"
addon.locales.deDE.DUNGEON_ENTRANCE_RECORDED = "Eingangsort aus einer erfassten Quelle."
addon.locales.frFR.DUNGEON_ENTRANCE_RECORDED = "Emplacement de l'entrée indiqué par une source."
addon.locales.esES.DUNGEON_ENTRANCE_RECORDED = "Ubicación de entrada registrada en una fuente."
addon.locales.itIT.DUNGEON_ENTRANCE_RECORDED = "Posizione dell'ingresso riportata da una fonte."
addon.locales.ptBR.DUNGEON_ENTRANCE_RECORDED = "Local de entrada registrado em uma fonte."
addon.locales.koKR.DUNGEON_ENTRANCE_RECORDED = "자료에 기록된 입구 위치입니다."
addon.locales.zhCN.DUNGEON_ENTRANCE_RECORDED = "来源资料记录的入口位置。"
addon.locales.zhTW.DUNGEON_ENTRANCE_RECORDED = "來源資料記錄的入口位置。"
addon.locales.deDE.QUEST_GIVER = "Questgeber"
addon.locales.frFR.QUEST_GIVER = "Donneur de quête"
addon.locales.esES.QUEST_GIVER = "Personaje que da la misión"
addon.locales.itIT.QUEST_GIVER = "Personaggio della missione"
addon.locales.ptBR.QUEST_GIVER = "Quem oferece a missão"
addon.locales.koKR.QUEST_GIVER = "퀘스트 제공자"
addon.locales.zhCN.QUEST_GIVER = "任务发布者"
addon.locales.zhTW.QUEST_GIVER = "任務提供者"
addon.locales.deDE.GIVER_LOCATION_UNKNOWN = "Der Aufenthaltsort des Questgebers ist noch unbekannt."
addon.locales.frFR.GIVER_LOCATION_UNKNOWN = "L'emplacement du donneur de quête est encore inconnu."
addon.locales.esES.GIVER_LOCATION_UNKNOWN = "Aún se desconoce la ubicación del personaje que da la misión."
addon.locales.itIT.GIVER_LOCATION_UNKNOWN = "La posizione del personaggio della missione è ancora sconosciuta."
addon.locales.ptBR.GIVER_LOCATION_UNKNOWN = "A localização de quem oferece a missão ainda é desconhecida."
addon.locales.koKR.GIVER_LOCATION_UNKNOWN = "퀘스트 제공자의 위치가 아직 알려지지 않았습니다."
addon.locales.zhCN.GIVER_LOCATION_UNKNOWN = "任务发布者的位置尚不明确。"
addon.locales.zhTW.GIVER_LOCATION_UNKNOWN = "任務提供者的位置尚不明確。"
addon.locales.deDE.GIVER_COORDINATES_UNKNOWN = "Genaue Koordinaten fehlen; nur das bekannte Gebiet kann angezeigt werden."
addon.locales.frFR.GIVER_COORDINATES_UNKNOWN = "Les coordonnées précises manquent ; seule la zone connue peut être affichée."
addon.locales.esES.GIVER_COORDINATES_UNKNOWN = "No hay coordenadas precisas; solo se puede mostrar la zona conocida."
addon.locales.itIT.GIVER_COORDINATES_UNKNOWN = "Le coordinate precise non sono disponibili; si può mostrare solo la zona nota."
addon.locales.ptBR.GIVER_COORDINATES_UNKNOWN = "As coordenadas exatas estão indisponíveis; apenas a área conhecida pode ser mostrada."
addon.locales.koKR.GIVER_COORDINATES_UNKNOWN = "정확한 좌표가 없어 알려진 지역만 표시할 수 있습니다."
addon.locales.zhCN.GIVER_COORDINATES_UNKNOWN = "没有精确坐标，只能显示已知区域。"
addon.locales.zhTW.GIVER_COORDINATES_UNKNOWN = "沒有精確座標，只能顯示已知區域。"
addon.locales.deDE.DUNGEON_ENTRANCE_SHARED = "Gemeinsamer Eingang; der Weg zum gewünschten Flügel führt innen weiter."
addon.locales.frFR.DUNGEON_ENTRANCE_SHARED = "Entrée commune ; le chemin vers votre aile continue à l'intérieur."
addon.locales.esES.DUNGEON_ENTRANCE_SHARED = "Entrada compartida; el camino hacia tu ala continúa dentro."
addon.locales.itIT.DUNGEON_ENTRANCE_SHARED = "Ingresso condiviso; il percorso per la tua ala prosegue all'interno."
addon.locales.ptBR.DUNGEON_ENTRANCE_SHARED = "Entrada compartilhada; o caminho até a sua ala continua lá dentro."
addon.locales.koKR.DUNGEON_ENTRANCE_SHARED = "공용 입구입니다. 내부에서 원하는 구역으로 이동하세요."
addon.locales.zhCN.DUNGEON_ENTRANCE_SHARED = "共用入口；进入后继续前往所需区域。"
addon.locales.zhTW.DUNGEON_ENTRANCE_SHARED = "共用入口；進入後繼續前往所需區域。"
addon.locales.deDE.DUNGEON_ENTRANCE_APPROACH = "Zugang zum Dungeon; das Portal liegt weiter innen."
addon.locales.frFR.DUNGEON_ENTRANCE_APPROACH = "Accès au donjon ; le portail se trouve plus loin à l'intérieur."
addon.locales.esES.DUNGEON_ENTRANCE_APPROACH = "Acceso a la mazmorra; el portal está más adentro."
addon.locales.itIT.DUNGEON_ENTRANCE_APPROACH = "Accesso alla spedizione; il portale si trova più all'interno."
addon.locales.ptBR.DUNGEON_ENTRANCE_APPROACH = "Acesso à masmorra; o portal fica mais adiante, lá dentro."
addon.locales.koKR.DUNGEON_ENTRANCE_APPROACH = "던전으로 향하는 입구입니다. 차원문은 더 안쪽에 있습니다."
addon.locales.zhCN.DUNGEON_ENTRANCE_APPROACH = "前往地下城的入口；传送门在更深处。"
addon.locales.zhTW.DUNGEON_ENTRANCE_APPROACH = "前往地城的入口；傳送門在更深處。"
addon.locales.deDE.ENTRANCE_SHARED_ACTION, addon.locales.deDE.ENTRANCE_APPROACH_ACTION = "Gemeinsamer Eingang", "Dungeon-Zugang"
addon.locales.frFR.ENTRANCE_SHARED_ACTION, addon.locales.frFR.ENTRANCE_APPROACH_ACTION = "Entrée commune", "Accès au donjon"
addon.locales.esES.ENTRANCE_SHARED_ACTION, addon.locales.esES.ENTRANCE_APPROACH_ACTION = "Entrada compartida", "Acceso a la mazmorra"
addon.locales.itIT.ENTRANCE_SHARED_ACTION, addon.locales.itIT.ENTRANCE_APPROACH_ACTION = "Ingresso condiviso", "Accesso alla spedizione"
addon.locales.ptBR.ENTRANCE_SHARED_ACTION, addon.locales.ptBR.ENTRANCE_APPROACH_ACTION = "Entrada compartilhada", "Acesso à masmorra"
addon.locales.koKR.ENTRANCE_SHARED_ACTION, addon.locales.koKR.ENTRANCE_APPROACH_ACTION = "공용 입구", "던전으로 이동"
addon.locales.zhCN.ENTRANCE_SHARED_ACTION, addon.locales.zhCN.ENTRANCE_APPROACH_ACTION = "共用入口", "前往地下城"
addon.locales.zhTW.ENTRANCE_SHARED_ACTION, addon.locales.zhTW.ENTRANCE_APPROACH_ACTION = "共用入口", "前往地城"
addon.locales.deDE.CHAIN_PREVIEW_NOTICE = "Ein Teil der Questreihe wird angezeigt; zum Anzeigen aller Schritte aufklappen."
addon.locales.frFR.CHAIN_PREVIEW_NOTICE = "Une partie de la suite est affichée ; développez-la pour voir chaque étape."
addon.locales.esES.CHAIN_PREVIEW_NOTICE = "Se muestra parte de la cadena; amplíala para ver todos los pasos."
addon.locales.itIT.CHAIN_PREVIEW_NOTICE = "È mostrata una parte della catena; espandila per vedere tutti i passaggi."
addon.locales.ptBR.CHAIN_PREVIEW_NOTICE = "Parte da sequência está visível; expanda para ver todas as etapas."
addon.locales.koKR.CHAIN_PREVIEW_NOTICE = "퀘스트 연계의 일부만 표시됩니다. 펼치면 모든 단계를 볼 수 있습니다."
addon.locales.zhCN.CHAIN_PREVIEW_NOTICE = "当前仅显示部分任务链；展开可查看所有步骤。"
addon.locales.zhTW.CHAIN_PREVIEW_NOTICE = "目前僅顯示部分任務鏈；展開可查看所有步驟。"
addon.locales.deDE.STORY_SHORT = "Handlung"
addon.locales.frFR.STORY_SHORT = "Histoire"
addon.locales.esES.STORY_SHORT = "Historia"
addon.locales.itIT.STORY_SHORT = "Storia"
addon.locales.ptBR.STORY_SHORT = "História"
addon.locales.koKR.STORY_SHORT = "이야기"
addon.locales.zhCN.STORY_SHORT = "剧情"
addon.locales.zhTW.STORY_SHORT = "劇情"
addon.locales.deDE.REQUIRED_STEP_SHORT = "Voraussetzung"
addon.locales.frFR.REQUIRED_STEP_SHORT = "Prérequis"
addon.locales.esES.REQUIRED_STEP_SHORT = "Requisito"
addon.locales.itIT.REQUIRED_STEP_SHORT = "Requisito"
addon.locales.ptBR.REQUIRED_STEP_SHORT = "Pré-requisito"
addon.locales.koKR.REQUIRED_STEP_SHORT = "선행 조건"
addon.locales.zhCN.REQUIRED_STEP_SHORT = "前置条件"
addon.locales.zhTW.REQUIRED_STEP_SHORT = "前置條件"
addon.locales.deDE.DETAIL_RECORDED_OBJECTIVES = "Verzeichnete Ziele"
addon.locales.frFR.DETAIL_RECORDED_OBJECTIVES = "Objectifs répertoriés"
addon.locales.esES.DETAIL_RECORDED_OBJECTIVES = "Objetivos registrados"
addon.locales.itIT.DETAIL_RECORDED_OBJECTIVES = "Obiettivi elencati"
addon.locales.ptBR.DETAIL_RECORDED_OBJECTIVES = "Objetivos registrados"
addon.locales.koKR.DETAIL_RECORDED_OBJECTIVES = "기록된 목표"
addon.locales.zhCN.DETAIL_RECORDED_OBJECTIVES = "已收录的目标"
addon.locales.zhTW.DETAIL_RECORDED_OBJECTIVES = "已收錄的目標"
addon.locales.deDE.CHAIN_TRUNCATED_NOTICE = "Nur ein Teil dieser Questreihe wird angezeigt."
addon.locales.frFR.CHAIN_TRUNCATED_NOTICE = "Seule une partie de cette suite est affichée."
addon.locales.esES.CHAIN_TRUNCATED_NOTICE = "Solo se muestra parte de esta cadena."
addon.locales.itIT.CHAIN_TRUNCATED_NOTICE = "È mostrata solo una parte di questa serie."
addon.locales.ptBR.CHAIN_TRUNCATED_NOTICE = "Apenas parte desta sequência é exibida."
addon.locales.koKR.CHAIN_TRUNCATED_NOTICE = "이 연계의 일부만 표시됩니다."
addon.locales.zhCN.CHAIN_TRUNCATED_NOTICE = "仅显示此任务链的一部分。"
addon.locales.zhTW.CHAIN_TRUNCATED_NOTICE = "僅顯示此任務鏈的一部分。"
addon.locales.deDE.VISIT_TURNIN = "Zum Abgabeort"
addon.locales.frFR.VISIT_TURNIN = "Aller au lieu de remise"
addon.locales.esES.VISIT_TURNIN = "Ir al lugar de entrega"
addon.locales.itIT.VISIT_TURNIN = "Vai al luogo di consegna"
addon.locales.ptBR.VISIT_TURNIN = "Ir ao local de entrega"
addon.locales.koKR.VISIT_TURNIN = "퀘스트 완료 지점 방문"
addon.locales.zhCN.VISIT_TURNIN = "前往任务交付地点"
addon.locales.zhTW.VISIT_TURNIN = "前往任務交付地點"
addon.locales.deDE.ANCESTOR_ACTION = "Nächster bekannter Schritt"
addon.locales.frFR.ANCESTOR_ACTION = "Prochaine étape connue"
addon.locales.esES.ANCESTOR_ACTION = "Siguiente paso conocido"
addon.locales.itIT.ANCESTOR_ACTION = "Prossimo passaggio noto"
addon.locales.ptBR.ANCESTOR_ACTION = "Próxima etapa conhecida"
addon.locales.koKR.ANCESTOR_ACTION = "다음으로 확인된 단계"
addon.locales.zhCN.ANCESTOR_ACTION = "下一个已知步骤"
addon.locales.zhTW.ANCESTOR_ACTION = "下一個已知步驟"
addon.locales.deDE.CATALOG_HIDE = "Dungeonliste ausblenden"
addon.locales.deDE.CATALOG_SHOW = "Dungeonliste anzeigen"
addon.locales.frFR.CATALOG_HIDE = "Masquer la liste des donjons"
addon.locales.frFR.CATALOG_SHOW = "Afficher la liste des donjons"
addon.locales.esES.CATALOG_HIDE = "Ocultar lista de mazmorras"
addon.locales.esES.CATALOG_SHOW = "Mostrar lista de mazmorras"
addon.locales.itIT.CATALOG_HIDE = "Nascondi elenco spedizioni"
addon.locales.itIT.CATALOG_SHOW = "Mostra elenco spedizioni"
addon.locales.ptBR.CATALOG_HIDE = "Ocultar lista de masmorras"
addon.locales.ptBR.CATALOG_SHOW = "Mostrar lista de masmorras"
addon.locales.koKR.CATALOG_HIDE = "던전 목록 숨기기"
addon.locales.koKR.CATALOG_SHOW = "던전 목록 표시"
addon.locales.zhCN.CATALOG_HIDE = "隐藏地下城列表"
addon.locales.zhCN.CATALOG_SHOW = "显示地下城列表"
addon.locales.zhTW.CATALOG_HIDE = "隱藏地城列表"
addon.locales.zhTW.CATALOG_SHOW = "顯示地城列表"
addon.locales.deDE.TAB_QUEST, addon.locales.deDE.TAB_SOURCES, addon.locales.deDE.TAB_STORY = "Quest", "Quellen", "Geschichte"
addon.locales.frFR.TAB_QUEST, addon.locales.frFR.TAB_SOURCES, addon.locales.frFR.TAB_STORY = "Quête", "Sources", "Histoire"
addon.locales.esES.TAB_QUEST, addon.locales.esES.TAB_SOURCES, addon.locales.esES.TAB_STORY = "Misión", "Fuentes", "Historia"
addon.locales.itIT.TAB_QUEST, addon.locales.itIT.TAB_SOURCES, addon.locales.itIT.TAB_STORY = "Missione", "Fonti", "Storia"
addon.locales.ptBR.TAB_QUEST, addon.locales.ptBR.TAB_SOURCES, addon.locales.ptBR.TAB_STORY = "Missão", "Fontes", "História"
addon.locales.koKR.TAB_QUEST, addon.locales.koKR.TAB_SOURCES, addon.locales.koKR.TAB_STORY = "퀘스트", "출처", "이야기"
addon.locales.zhCN.TAB_QUEST, addon.locales.zhCN.TAB_SOURCES, addon.locales.zhCN.TAB_STORY = "任务", "来源", "故事"
addon.locales.zhTW.TAB_QUEST, addon.locales.zhTW.TAB_SOURCES, addon.locales.zhTW.TAB_STORY = "任務", "來源", "故事"
addon.locales.deDE.DETAIL_STORY_UNAVAILABLE = "Der Questtext ist noch nicht verfügbar. Öffne das Questangebot, um ihn zu speichern."
addon.locales.frFR.DETAIL_STORY_UNAVAILABLE = "Le texte de la quête n’est pas encore disponible. Ouvrez l’offre de quête pour l’enregistrer."
addon.locales.esES.DETAIL_STORY_UNAVAILABLE = "El texto de la misión aún no está disponible. Abre la oferta de la misión para guardarlo."
addon.locales.itIT.DETAIL_STORY_UNAVAILABLE = "Il testo della missione non è ancora disponibile. Apri la finestra di offerta della missione per salvarlo."
addon.locales.ptBR.DETAIL_STORY_UNAVAILABLE = "O texto da missão ainda não está disponível. Abra a oferta da missão para salvá-lo."
addon.locales.koKR.DETAIL_STORY_UNAVAILABLE = "퀘스트 내용이 아직 없습니다. 퀘스트 수락 창을 열면 저장됩니다."
addon.locales.zhCN.DETAIL_STORY_UNAVAILABLE = "任务文本暂不可用。打开任务接受窗口即可保存。"
addon.locales.zhTW.DETAIL_STORY_UNAVAILABLE = "任務文字尚未提供。開啟任務接受視窗即可儲存。"
addon.locales.deDE.ITEM_SOURCE_SUMMARY = "Erfasste Quellen: %d. Siehe %s."
addon.locales.frFR.ITEM_SOURCE_SUMMARY = "Sources répertoriées : %d. Voir %s."
addon.locales.esES.ITEM_SOURCE_SUMMARY = "Fuentes registradas: %d. Ver %s."
addon.locales.itIT.ITEM_SOURCE_SUMMARY = "Fonti elencate: %d. Vedi %s."
addon.locales.ptBR.ITEM_SOURCE_SUMMARY = "Fontes listadas: %d. Veja %s."
addon.locales.koKR.ITEM_SOURCE_SUMMARY = "등록된 출처: %d곳. %s 탭을 확인하세요."
addon.locales.zhCN.ITEM_SOURCE_SUMMARY = "已列来源：%d 个。查看“%s”。"
addon.locales.zhTW.ITEM_SOURCE_SUMMARY = "已列來源：%d 個。查看「%s」。"
addon.locales.deDE.REPORT_ISSUE, addon.locales.deDE.SUPPORT_AUTHOR, addon.locales.deDE.CLOSE = "Problem melden", "Projekt unterstützen", "Schließen"
addon.locales.frFR.REPORT_ISSUE, addon.locales.frFR.SUPPORT_AUTHOR, addon.locales.frFR.CLOSE = "Signaler un problème", "Soutenir le projet", "Fermer"
addon.locales.esES.REPORT_ISSUE, addon.locales.esES.SUPPORT_AUTHOR, addon.locales.esES.CLOSE = "Informar de un problema", "Apoyar el proyecto", "Cerrar"
addon.locales.itIT.REPORT_ISSUE, addon.locales.itIT.SUPPORT_AUTHOR, addon.locales.itIT.CLOSE = "Segnala un problema", "Sostieni il progetto", "Chiudi"
addon.locales.ptBR.REPORT_ISSUE, addon.locales.ptBR.SUPPORT_AUTHOR, addon.locales.ptBR.CLOSE = "Relatar um problema", "Apoiar o projeto", "Fechar"
addon.locales.koKR.REPORT_ISSUE, addon.locales.koKR.SUPPORT_AUTHOR, addon.locales.koKR.CLOSE = "문제 신고", "프로젝트 후원", "닫기"
addon.locales.zhCN.REPORT_ISSUE, addon.locales.zhCN.SUPPORT_AUTHOR, addon.locales.zhCN.CLOSE = "报告问题", "支持项目", "关闭"
addon.locales.zhTW.REPORT_ISSUE, addon.locales.zhTW.SUPPORT_AUTHOR, addon.locales.zhTW.CLOSE = "回報問題", "支持專案", "關閉"
addon.locales.deDE.LEVEL_FILTER, addon.locales.deDE.CHARACTER_FILTER, addon.locales.deDE.FILTER_SWITCH = "Stufenfilter", "Charakterfilter", "Klicken: %s"
addon.locales.frFR.LEVEL_FILTER, addon.locales.frFR.CHARACTER_FILTER, addon.locales.frFR.FILTER_SWITCH = "Filtre de niveau", "Filtre de personnage", "Clic : %s"
addon.locales.esES.LEVEL_FILTER, addon.locales.esES.CHARACTER_FILTER, addon.locales.esES.FILTER_SWITCH = "Filtro de nivel", "Filtro de personaje", "Clic: %s"
addon.locales.itIT.LEVEL_FILTER, addon.locales.itIT.CHARACTER_FILTER, addon.locales.itIT.FILTER_SWITCH = "Filtro di livello", "Filtro del personaggio", "Clic: %s"
addon.locales.ptBR.LEVEL_FILTER, addon.locales.ptBR.CHARACTER_FILTER, addon.locales.ptBR.FILTER_SWITCH = "Filtro de nível", "Filtro de personagem", "Clique: %s"
addon.locales.koKR.LEVEL_FILTER, addon.locales.koKR.CHARACTER_FILTER, addon.locales.koKR.FILTER_SWITCH = "레벨 필터", "캐릭터 필터", "클릭: %s"
addon.locales.zhCN.LEVEL_FILTER, addon.locales.zhCN.CHARACTER_FILTER, addon.locales.zhCN.FILTER_SWITCH = "等级筛选", "角色筛选", "点击：%s"
addon.locales.zhTW.LEVEL_FILTER, addon.locales.zhTW.CHARACTER_FILTER, addon.locales.zhTW.FILTER_SWITCH = "等級篩選", "角色篩選", "點擊：%s"
addon.locales.deDE.DUNGEON_QUEST_SHORT = "Dungeon"
addon.locales.frFR.DUNGEON_QUEST_SHORT = "Donjon"
addon.locales.esES.DUNGEON_QUEST_SHORT = "Mazmorra"
addon.locales.itIT.DUNGEON_QUEST_SHORT = "Spedizione"
addon.locales.ptBR.DUNGEON_QUEST_SHORT = "Masmorra"
addon.locales.koKR.DUNGEON_QUEST_SHORT = "던전"
addon.locales.zhCN.DUNGEON_QUEST_SHORT = "地下城"
addon.locales.zhTW.DUNGEON_QUEST_SHORT = "地城"

local cardStrings = {
    enUS = { "%d–%d · Quests: %d", "Quest status", "Only listed quests for your current character.", "All listed quests completed.", "Quests ready to turn in.", "Quests available to accept.", "Quests in your log.", "Quest availability is not yet confirmed.", "Known quest requirements are not met.", "No listed quests match this character.", "More levels needed for the remaining quests.", "Quest data is not available yet." },
    ruRU = { "%d–%d · Заданий: %d", "Состояние заданий", "Только перечисленные задания для текущего персонажа.", "Все перечисленные задания выполнены.", "Есть задания, готовые к сдаче.", "Есть задания, которые можно принять.", "Есть задания в журнале.", "Доступность заданий пока не подтверждена.", "Известные требования заданий не выполнены.", "Нет перечисленных заданий для этого персонажа.", "Для оставшихся заданий нужен более высокий уровень.", "Данные о заданиях пока отсутствуют." },
    deDE = { "%d–%d · Quests: %d", "Queststatus", "Nur aufgeführte Quests für deinen aktuellen Charakter.", "Alle aufgeführten Quests abgeschlossen.", "Quests zur Abgabe bereit.", "Quests können angenommen werden.", "Quests im Questlog.", "Die Verfügbarkeit der Quests ist noch unbestätigt.", "Bekannte Questvoraussetzungen sind nicht erfüllt.", "Keine aufgeführten Quests passen zu diesem Charakter.", "Für die verbleibenden Quests ist eine höhere Stufe nötig.", "Questdaten sind noch nicht verfügbar." },
    frFR = { "%d–%d · Quêtes : %d", "État des quêtes", "Uniquement les quêtes répertoriées pour votre personnage actuel.", "Toutes les quêtes répertoriées sont terminées.", "Des quêtes sont prêtes à être rendues.", "Des quêtes peuvent être acceptées.", "Des quêtes sont dans votre journal.", "La disponibilité des quêtes reste à confirmer.", "Les prérequis connus des quêtes ne sont pas remplis.", "Aucune quête répertoriée ne correspond à ce personnage.", "Les quêtes restantes nécessitent un niveau plus élevé.", "Les données des quêtes ne sont pas encore disponibles." },
    esES = { "%d–%d · Misiones: %d", "Estado de misiones", "Solo las misiones enumeradas para tu personaje actual.", "Todas las misiones enumeradas están completadas.", "Hay misiones listas para entregar.", "Hay misiones que puedes aceptar.", "Hay misiones en tu registro.", "La disponibilidad de las misiones aún no está confirmada.", "No se cumplen los requisitos conocidos de las misiones.", "Ninguna misión enumerada corresponde a este personaje.", "Las misiones restantes requieren un nivel más alto.", "Los datos de misiones aún no están disponibles." },
    itIT = { "%d–%d · Missioni: %d", "Stato delle missioni", "Solo le missioni elencate per il personaggio attuale.", "Tutte le missioni elencate sono completate.", "Ci sono missioni pronte da consegnare.", "Ci sono missioni disponibili da accettare.", "Ci sono missioni nel diario.", "La disponibilità delle missioni non è ancora confermata.", "I requisiti noti delle missioni non sono soddisfatti.", "Nessuna missione elencata è adatta a questo personaggio.", "Le missioni rimanenti richiedono un livello più alto.", "I dati delle missioni non sono ancora disponibili." },
    ptBR = { "%d–%d · Missões: %d", "Estado das missões", "Somente as missões listadas para seu personagem atual.", "Todas as missões listadas foram concluídas.", "Há missões prontas para entregar.", "Há missões disponíveis para aceitar.", "Há missões no seu registro.", "A disponibilidade das missões ainda não foi confirmada.", "Os requisitos conhecidos das missões não foram atendidos.", "Nenhuma missão listada corresponde a este personagem.", "As missões restantes exigem um nível maior.", "Os dados das missões ainda não estão disponíveis." },
    koKR = { "%d–%d · 퀘스트: %d", "퀘스트 상태", "현재 캐릭터에 해당하는 목록의 퀘스트만 표시합니다.", "목록의 모든 퀘스트를 완료했습니다.", "제출할 수 있는 퀘스트가 있습니다.", "수락할 수 있는 퀘스트가 있습니다.", "퀘스트 목록에 진행 중인 퀘스트가 있습니다.", "퀘스트 수락 가능 여부가 아직 확인되지 않았습니다.", "알려진 퀘스트 조건을 충족하지 못했습니다.", "이 캐릭터에 해당하는 퀘스트가 목록에 없습니다.", "남은 퀘스트를 하려면 레벨을 더 올려야 합니다.", "퀘스트 데이터가 아직 없습니다." },
    zhCN = { "%d–%d · 任务：%d", "任务状态", "仅统计列表中适合当前角色的任务。", "列表中的所有任务均已完成。", "有可以交付的任务。", "有可以接受的任务。", "任务日志中有进行中的任务。", "任务是否可接受尚未确认。", "尚未满足已知的任务要求。", "列表中没有适合此角色的任务。", "剩余任务需要更高等级。", "暂时没有任务数据。" },
    zhTW = { "%d–%d · 任務：%d", "任務狀態", "僅統計清單中適合目前角色的任務。", "清單中的所有任務均已完成。", "有可以交付的任務。", "有可以接受的任務。", "任務日誌中有進行中的任務。", "任務是否可接受尚未確認。", "尚未滿足已知的任務要求。", "清單中沒有適合此角色的任務。", "剩餘任務需要更高等級。", "暫時沒有任務資料。" },
}
local cardKeys = { "CATALOG_COMPACT_META", "DUNGEON_STATUS", "DUNGEON_STATUS_SCOPE", "DUNGEON_STATUS_COMPLETED", "DUNGEON_STATUS_READY", "DUNGEON_STATUS_AVAILABLE", "DUNGEON_STATUS_ACTIVE", "DUNGEON_STATUS_UNKNOWN", "DUNGEON_STATUS_LOCKED", "DUNGEON_STATUS_UNAVAILABLE", "DUNGEON_STATUS_LEVEL", "DUNGEON_STATUS_EMPTY" }
for locale, values in pairs(cardStrings) do
    for index, key in ipairs(cardKeys) do addon.locales[locale][key] = values[index] end
end

local detailStrings = {
    enUS = { "Quest level: %d", "Required level: %d", "Quest giver", "Rewards", "Story", "Text not recorded yet", "Read story", "Collapse story" },
    ruRU = { "Уровень задания: %d", "Минимальный уровень: %d", "Кто выдаёт", "Награды", "История", "Текст пока не сохранён", "Читать историю", "Свернуть историю" },
    deDE = { "Queststufe: %d", "Mindeststufe: %d", "Auftraggeber", "Belohnungen", "Geschichte", "Text noch nicht gespeichert", "Geschichte lesen", "Geschichte einklappen" },
    frFR = { "Niveau de quête : %d", "Niveau requis : %d", "Donneur de quête", "Récompenses", "Histoire", "Texte pas encore enregistré", "Lire l’histoire", "Réduire l’histoire" },
    esES = { "Nivel de misión: %d", "Nivel requerido: %d", "Quién la ofrece", "Recompensas", "Historia", "Texto aún no guardado", "Leer historia", "Contraer historia" },
    itIT = { "Livello missione: %d", "Livello richiesto: %d", "Chi offre la missione", "Ricompense", "Storia", "Testo non ancora salvato", "Leggi la storia", "Riduci la storia" },
    ptBR = { "Nível da missão: %d", "Nível necessário: %d", "Quem oferece", "Recompensas", "História", "Texto ainda não salvo", "Ler história", "Recolher história" },
    koKR = { "퀘스트 레벨: %d", "필요 레벨: %d", "퀘스트 제공자", "보상", "이야기", "아직 저장된 내용이 없습니다", "이야기 읽기", "이야기 접기" },
    zhCN = { "任务等级：%d", "需要等级：%d", "任务给予者", "奖励", "故事", "尚未保存任务文本", "阅读故事", "收起故事" },
    zhTW = { "任務等級：%d", "需要等級：%d", "任務給予者", "獎勵", "故事", "尚未儲存任務文本", "閱讀故事", "收起故事" },
}
local detailKeys = { "DETAIL_LEVEL", "DETAIL_MIN_LEVEL", "DETAIL_GIVER", "DETAIL_REWARDS", "DETAIL_STORY", "DETAIL_STORY_EMPTY", "DETAIL_STORY_READ", "DETAIL_STORY_HIDE" }
for locale, values in pairs(detailStrings) do
    for index, key in ipairs(detailKeys) do addon.locales[locale][key] = values[index] end
end

local filterStrings = {
    enUS = { "All levels", "My level", "Mine", "All quests" },
    ruRU = { "Все уровни", "Мой уровень", "Мои", "Все задания" },
    deDE = { "Alle Stufen", "Mein Level", "Meine", "Alle Quests" },
    frFR = { "Tous niveaux", "Mon niveau", "Moi", "Tous" },
    esES = { "Todos los niveles", "Mi nivel", "Mías", "Todas" },
    itIT = { "Tutti i livelli", "Il mio livello", "Mie", "Tutte" },
    ptBR = { "Todos os níveis", "Meu nível", "Minhas", "Todas" },
    koKR = { "모든 레벨", "내 레벨", "내 것", "전체" },
    zhCN = { "所有等级", "我的等级", "我的", "全部" },
    zhTW = { "所有等級", "我的等級", "我的", "全部" },
}
local filterKeys = { "FILTER_LEVEL_ALL", "FILTER_LEVEL_CURRENT", "FILTER_QUEST_MINE", "FILTER_QUEST_ALL" }
for locale, values in pairs(filterStrings) do
    for index, key in ipairs(filterKeys) do addon.locales[locale][key] = values[index] end
end

local chainStrings = {
    enUS = { "Expand quest chain", "Collapse quest chain" },
    ruRU = { "Развернуть цепочку", "Свернуть цепочку" },
    deDE = { "Questreihe öffnen", "Questreihe schließen" },
    frFR = { "Afficher la suite", "Réduire la suite" },
    esES = { "Expandir cadena", "Contraer cadena" },
    itIT = { "Espandi catena", "Comprimi catena" },
    ptBR = { "Expandir cadeia", "Recolher cadeia" },
    koKR = { "퀘스트 연계 펼치기", "퀘스트 연계 접기" },
    zhCN = { "展开任务链", "收起任务链" },
    zhTW = { "展開任務鏈", "收起任務鏈" },
}
for locale, values in pairs(chainStrings) do
    addon.locales[locale].CHAIN_EXPAND, addon.locales[locale].CHAIN_COLLAPSE = values[1], values[2]
end

local acquisitionStrings = {
    enUS = { "More locations and sources", "Hide extra locations and sources", "Guaranteed", "Turn in" },
    ruRU = { "Другие места и источники", "Скрыть другие места и источники", "Гарантированные", "Сдать" },
    deDE = { "Weitere Orte und Quellen", "Weitere Orte und Quellen ausblenden", "Garantiert", "Abgeben" },
    frFR = { "Autres lieux et sources", "Masquer les autres lieux et sources", "Garanties", "Rendre" },
    esES = { "Más ubicaciones y fuentes", "Ocultar ubicaciones y fuentes adicionales", "Garantizadas", "Entregar" },
    itIT = { "Altri luoghi e fonti", "Nascondi altri luoghi e fonti", "Garantite", "Consegna" },
    ptBR = { "Outros locais e fontes", "Ocultar outros locais e fontes", "Garantidas", "Entregar" },
    koKR = { "다른 위치와 획득처", "추가 위치와 획득처 숨기기", "확정 보상", "완료 보고" },
    zhCN = { "更多位置和来源", "隐藏其他位置和来源", "必得奖励", "交付" },
    zhTW = { "更多位置與來源", "隱藏其他位置與來源", "必得獎勵", "交付" },
}
local acquisitionKeys = { "DETAIL_ACQUISITION", "DETAIL_ACQUISITION_HIDE", "DETAIL_GUARANTEED", "DETAIL_TURNIN" }
for locale, values in pairs(acquisitionStrings) do
    for index, key in ipairs(acquisitionKeys) do addon.locales[locale][key] = values[index] end
end

local starterDetails = {
    enUS = { "Start with this item", "Starter item source is not yet known." },
    ruRU = { "Задание начинает предмет", "Пока неизвестно, где получить стартовый предмет." },
    deDE = { "Queststart durch Gegenstand", "Die Quelle des Startgegenstands ist noch unbekannt." },
    frFR = { "Objet qui lance la quête", "La source de l’objet de départ est encore inconnue." },
    esES = { "Objeto que inicia la misión", "Aún se desconoce dónde obtener el objeto inicial." },
    itIT = { "Oggetto che avvia la missione", "La provenienza dell’oggetto iniziale è ancora sconosciuta." },
    ptBR = { "Item que inicia a missão", "Ainda não se sabe onde obter o item inicial." },
    koKR = { "퀘스트 시작 아이템", "시작 아이템의 획득처를 아직 알 수 없습니다." },
    zhCN = { "任务起始物品", "起始物品的来源尚不明确。" },
    zhTW = { "任務起始物品", "起始物品的來源尚不明確。" },
}
for locale, values in pairs(starterDetails) do
    addon.locales[locale].DETAIL_START_ITEM, addon.locales[locale].START_ITEM_LOCATION_UNKNOWN = values[1], values[2]
end

local itemStarterMarks = {
    deDE = "Gegenstand aufnehmen",
    frFR = "Récupérer l’objet",
    esES = "Recoger el objeto",
    itIT = "Raccogli l’oggetto",
    ptBR = "Coletar o item",
    koKR = "아이템 획득",
    zhCN = "拾取物品开始",
    zhTW = "拾取物品開始",
}
for locale, value in pairs(itemStarterMarks) do addon.locales[locale].PREP_item = value end

local routeActions = {
    enUS = { "Use this route", "Use automatic choice" },
    ruRU = { "Выбрать этот путь", "Выбирать автоматически" },
    deDE = { "Diese Route wählen", "Automatische Auswahl" },
    frFR = { "Choisir cet itinéraire", "Choix automatique" },
    esES = { "Elegir esta ruta", "Elegir automáticamente" },
    itIT = { "Scegli questo percorso", "Scelta automatica" },
    ptBR = { "Escolher esta rota", "Escolha automática" },
    koKR = { "이 경로 선택", "자동 선택 사용" },
    zhCN = { "选择此路线", "自动选择路线" },
    zhTW = { "選擇此路線", "自動選擇路線" },
}
for locale, values in pairs(routeActions) do
    addon.locales[locale].BRANCH_PREFER, addon.locales[locale].BRANCH_RESET = values[1], values[2]
end
local objectiveCaptions = { enUS = "Objectives", ruRU = "Цели", deDE = "Ziele", frFR = "Objectifs",
    esES = "Objetivos", itIT = "Obiettivi", ptBR = "Objetivos", koKR = "목표", zhCN = "目标", zhTW = "目標" }
for locale, value in pairs(objectiveCaptions) do addon.locales[locale].DETAIL_OBJECTIVES = value end

local requirementOwners = { enUS = "Required for: %s", ruRU = "Нужно для: %s", deDE = "Benötigt für: %s",
    frFR = "Requis pour : %s", esES = "Requisito para: %s", itIT = "Necessario per: %s",
    ptBR = "Necessário para: %s", koKR = "필요한 퀘스트: %s", zhCN = "前置任务归属：%s", zhTW = "前置任務歸屬：%s" }
for locale, value in pairs(requirementOwners) do addon.locales[locale].REQUIREMENT_FOR = value end

local directNavigationHints = {
    enUS = { "Choose a starting point on Sources.", "Navigation is currently unavailable.", "Starts from an item. Click to see its source details." },
    ruRU = { "Выберите место получения на вкладке «Источники».", "Навигация сейчас недоступна.", "Задание начинается предметом. Нажмите, чтобы узнать его источник." },
    deDE = { "Wähle einen Startpunkt unter Quellen.", "Navigation ist derzeit nicht verfügbar.", "Beginnt durch einen Gegenstand. Klicken, um die Quelle anzuzeigen." },
    frFR = { "Choisissez un point de départ dans Sources.", "La navigation est actuellement indisponible.", "Cette quête commence par un objet. Cliquez pour voir sa source." },
    esES = { "Elige un punto de inicio en Fuentes.", "La navegación no está disponible en este momento.", "Se inicia con un objeto. Haz clic para ver su origen." },
    itIT = { "Scegli un punto di partenza nella scheda Fonti.", "La navigazione non è al momento disponibile.", "Inizia con un oggetto. Clicca per vedere la sua provenienza." },
    ptBR = { "Escolha um ponto de início em Fontes.", "A navegação está indisponível no momento.", "Começa com um item. Clique para ver sua origem." },
    koKR = { "출처 탭에서 퀘스트 시작 지점을 선택하세요.", "현재 길 안내를 사용할 수 없습니다.", "아이템으로 시작하는 퀘스트입니다. 클릭하여 획득처를 확인하세요." },
    zhCN = { "请在“来源”中选择任务起始点。", "导航暂时不可用。", "此任务由物品触发。点击查看物品来源。" },
    zhTW = { "請在「來源」中選擇任務起始點。", "導航暫時無法使用。", "此任務由物品觸發。點擊查看物品來源。" },
}
for locale, values in pairs(directNavigationHints) do
    addon.locales[locale].GIVER_CHOICES_REQUIRED, addon.locales[locale].NAVIGATION_UNAVAILABLE,
        addon.locales[locale].START_ITEM_NAVIGATION = values[1], values[2], values[3]
end

local sourceInspectionLabels = {
    enUS = { "Quest sources", "Click to view this quest's starting sources." },
    ruRU = { "Где взять задание", "Нажмите, чтобы посмотреть источники задания." },
    deDE = { "Questquellen", "Klicken, um die Startquellen dieser Quest anzuzeigen." },
    frFR = { "Sources de la quête", "Cliquez pour voir les sources de départ de cette quête." },
    esES = { "Origen de la misión", "Haz clic para ver dónde se inicia esta misión." },
    itIT = { "Origine della missione", "Clicca per vedere dove inizia questa missione." },
    ptBR = { "Origem da missão", "Clique para ver onde esta missão começa." },
    koKR = { "퀘스트 시작 정보", "클릭하여 이 퀘스트의 시작 경로를 확인하세요." },
    zhCN = { "任务来源", "点击查看此任务的起始来源。" },
    zhTW = { "任務來源", "點擊查看此任務的起始來源。" },
}
for locale, values in pairs(sourceInspectionLabels) do
    addon.locales[locale].SOURCE_DETAILS, addon.locales[locale].SOURCE_DETAILS_HINT = values[1], values[2]
end

local unknownSourcePositions = {
    enUS = "Exact location is not yet known.",
    ruRU = "Точное местоположение пока неизвестно.",
    deDE = "Der genaue Standort ist noch nicht bekannt.",
    frFR = "L'emplacement exact n'est pas encore connu.",
    esES = "La ubicación exacta aún no se conoce.",
    itIT = "La posizione esatta non è ancora nota.",
    ptBR = "A localização exata ainda não é conhecida.",
    koKR = "정확한 위치는 아직 알려지지 않았습니다.",
    zhCN = "确切位置尚不明确。",
    zhTW = "確切位置尚不明確。",
}
for locale, value in pairs(unknownSourcePositions) do addon.locales[locale].SOURCE_POSITION_UNKNOWN = value end

local summonSourceLabels = {
    enUS = { "Use %s to create %s.", "Use the listed item to create this object." },
    ruRU = { "Используйте %s — появится %s.", "Используйте указанный предмет, чтобы создать этот объект." },
    deDE = { "Verwende %s, um %s zu erschaffen.", "Verwende den angezeigten Gegenstand, um dieses Objekt zu erschaffen." },
    frFR = { "Utilisez %s pour créer %s.", "Utilisez l'objet indiqué pour créer cet objet." },
    esES = { "Usa %s para crear %s.", "Usa el objeto indicado para crear este objeto." },
    itIT = { "Usa %s per creare %s.", "Usa l'oggetto indicato per creare questo oggetto." },
    ptBR = { "Use %s para criar %s.", "Use o item indicado para criar este objeto." },
    koKR = { "%s 아이템을 사용하여 %s 생성", "표시된 아이템을 사용하여 이 오브젝트를 생성하세요." },
    zhCN = { "使用%s召唤%s。", "使用所示物品召唤此物体。" },
    zhTW = { "使用%s召喚%s。", "使用所示物品召喚此物件。" },
}
for locale, values in pairs(summonSourceLabels) do
    addon.locales[locale].SOURCE_SUMMON_ITEM, addon.locales[locale].SOURCE_SUMMON_HINT = values[1], values[2]
end

local unknownQuestStarts = {
    enUS = "How to start this quest is not yet known.",
    ruRU = "Способ начала этого задания пока неизвестен.",
    deDE = "Wie diese Quest beginnt, ist noch nicht bekannt.",
    frFR = "La façon de commencer cette quête n'est pas encore connue.",
    esES = "Aún no se sabe cómo iniciar esta misión.",
    itIT = "Non è ancora noto come iniziare questa missione.",
    ptBR = "Ainda não se sabe como iniciar esta missão.",
    koKR = "이 퀘스트를 시작하는 방법은 아직 알려지지 않았습니다.",
    zhCN = "此任务的开始方式尚不明确。",
    zhTW = "此任務的開始方式尚不明確。",
}
for locale, value in pairs(unknownQuestStarts) do addon.locales[locale].QUEST_START_UNKNOWN = value end

local dungeonMapLabels = {
    deDE = {
        DUNGEON_MAP_OPEN = "Dungeonkarte",
        DUNGEON_MAP_BACK = "Zurück zu den Details",
        DUNGEON_MAP_RETRY = "Erneut versuchen",
        DUNGEON_MAP_UNAVAILABLE = "Für diesen Dungeon ist keine Karte verfügbar.",
        DUNGEON_MAP_SHARED = "Diese Karte umfasst mehrere Dungeonflügel.",
        DUNGEON_MAP_FLOOR = "Ebene %d",
        DUNGEON_MAP_PREVIOUS = "Vorherige Ebene",
        DUNGEON_MAP_NEXT = "Nächste Ebene",
    },
    frFR = {
        DUNGEON_MAP_OPEN = "Carte du donjon",
        DUNGEON_MAP_BACK = "Retour aux détails",
        DUNGEON_MAP_RETRY = "Réessayer",
        DUNGEON_MAP_UNAVAILABLE = "Aucune carte n’est disponible pour ce donjon.",
        DUNGEON_MAP_SHARED = "Cette carte couvre plusieurs ailes du donjon.",
        DUNGEON_MAP_FLOOR = "Niveau %d",
        DUNGEON_MAP_PREVIOUS = "Niveau précédent",
        DUNGEON_MAP_NEXT = "Niveau suivant",
    },
    esES = {
        DUNGEON_MAP_OPEN = "Mapa de la mazmorra",
        DUNGEON_MAP_BACK = "Volver a los detalles",
        DUNGEON_MAP_RETRY = "Reintentar",
        DUNGEON_MAP_UNAVAILABLE = "No hay un mapa disponible para esta mazmorra.",
        DUNGEON_MAP_SHARED = "Este mapa abarca varias alas de la mazmorra.",
        DUNGEON_MAP_FLOOR = "Planta %d",
        DUNGEON_MAP_PREVIOUS = "Planta anterior",
        DUNGEON_MAP_NEXT = "Planta siguiente",
    },
    itIT = {
        DUNGEON_MAP_OPEN = "Mappa della spedizione",
        DUNGEON_MAP_BACK = "Torna ai dettagli",
        DUNGEON_MAP_RETRY = "Riprova",
        DUNGEON_MAP_UNAVAILABLE = "Non è disponibile una mappa per questa spedizione.",
        DUNGEON_MAP_SHARED = "Questa mappa comprende più ali della spedizione.",
        DUNGEON_MAP_FLOOR = "Piano %d",
        DUNGEON_MAP_PREVIOUS = "Piano precedente",
        DUNGEON_MAP_NEXT = "Piano successivo",
    },
    ptBR = {
        DUNGEON_MAP_OPEN = "Mapa da masmorra",
        DUNGEON_MAP_BACK = "Voltar aos detalhes",
        DUNGEON_MAP_RETRY = "Tentar novamente",
        DUNGEON_MAP_UNAVAILABLE = "Não há mapa disponível para esta masmorra.",
        DUNGEON_MAP_SHARED = "Este mapa abrange várias alas da masmorra.",
        DUNGEON_MAP_FLOOR = "Andar %d",
        DUNGEON_MAP_PREVIOUS = "Andar anterior",
        DUNGEON_MAP_NEXT = "Próximo andar",
    },
    koKR = {
        DUNGEON_MAP_OPEN = "던전 지도",
        DUNGEON_MAP_BACK = "상세 정보로 돌아가기",
        DUNGEON_MAP_RETRY = "다시 시도",
        DUNGEON_MAP_UNAVAILABLE = "이 던전의 지도를 사용할 수 없습니다.",
        DUNGEON_MAP_SHARED = "여러 던전 구역이 함께 표시된 지도입니다.",
        DUNGEON_MAP_FLOOR = "%d층",
        DUNGEON_MAP_PREVIOUS = "이전 층",
        DUNGEON_MAP_NEXT = "다음 층",
    },
    zhCN = {
        DUNGEON_MAP_OPEN = "地下城地图",
        DUNGEON_MAP_BACK = "返回详情",
        DUNGEON_MAP_RETRY = "重试",
        DUNGEON_MAP_UNAVAILABLE = "此地下城暂无可用地图。",
        DUNGEON_MAP_SHARED = "此地图包含地下城的多个区域。",
        DUNGEON_MAP_FLOOR = "第%d层",
        DUNGEON_MAP_PREVIOUS = "上一层",
        DUNGEON_MAP_NEXT = "下一层",
    },
    zhTW = {
        DUNGEON_MAP_OPEN = "地城地圖",
        DUNGEON_MAP_BACK = "返回詳細資訊",
        DUNGEON_MAP_RETRY = "重試",
        DUNGEON_MAP_UNAVAILABLE = "此地城目前沒有可用地圖。",
        DUNGEON_MAP_SHARED = "此地圖包含地城的多個區域。",
        DUNGEON_MAP_FLOOR = "第%d層",
        DUNGEON_MAP_PREVIOUS = "上一層",
        DUNGEON_MAP_NEXT = "下一層",
    },
}
for locale, values in pairs(dungeonMapLabels) do
    for key, value in pairs(values) do addon.locales[locale][key] = value end
end

local relatedSearchLabels = {
    deDE = "Zugehöriger Schritt: %s",
    frFR = "Étape liée : %s",
    esES = "Paso relacionado: %s",
    itIT = "Passaggio collegato: %s",
    ptBR = "Etapa relacionada: %s",
    koKR = "관련 단계: %s",
    zhCN = "相关步骤：%s",
    zhTW = "相關步驟：%s",
}
for locale, value in pairs(relatedSearchLabels) do
    addon.locales[locale].SEARCH_RELATED_STEP = value
end

do
    local overviewLabels = {
        deDE = {
            OVERVIEW_PREPARATION = "Fortschritt der aufgeführten Quests",
            OVERVIEW_STATUS_ACTIVE = "Abgabebereit: %d · In Arbeit: %d",
            OVERVIEW_STATUS_RECORDED = "Abgeschlossen: %d · Ungeklärt: %d",
            OVERVIEW_STATUS_COUNT = "%s: %d",
            OVERVIEW_KNOWN_STEPS = "Aus eurem Questlog",
            OVERVIEW_NEXT_STEPS = "Nächste Schritte",
            OVERVIEW_NO_KNOWN_STEPS = "Keine Schritte aufgeführt. Wählt eine Quest für Details.",
            OVERVIEW_UNCERTAIN = "Einige Questbedingungen oder Angaben sind noch nicht bestätigt.",
            OVERVIEW_SUPPORTING_QUEST = "Unterstützende Quest",
            OVERVIEW_MORE_STEPS = "%d weitere Schritte werden hier nicht angezeigt.",
        },
        frFR = {
            OVERVIEW_PREPARATION = "Progression des quêtes listées",
            OVERVIEW_STATUS_ACTIVE = "À rendre : %d · En cours : %d",
            OVERVIEW_STATUS_RECORDED = "Terminées : %d · Incertaines : %d",
            OVERVIEW_STATUS_COUNT = "%s : %d",
            OVERVIEW_KNOWN_STEPS = "Dans votre journal de quêtes",
            OVERVIEW_NEXT_STEPS = "Prochaines étapes",
            OVERVIEW_NO_KNOWN_STEPS = "Aucune étape listée. Sélectionnez une quête pour les détails.",
            OVERVIEW_UNCERTAIN = "Certaines conditions ou informations sur les quêtes restent à vérifier.",
            OVERVIEW_SUPPORTING_QUEST = "Quête associée",
            OVERVIEW_MORE_STEPS = "%d autres étapes ne sont pas affichées ici.",
        },
        esES = {
            OVERVIEW_PREPARATION = "Progreso de las misiones listadas",
            OVERVIEW_STATUS_ACTIVE = "Para entregar: %d · En curso: %d",
            OVERVIEW_STATUS_RECORDED = "Completadas: %d · Sin verificar: %d",
            OVERVIEW_STATUS_COUNT = "%s: %d",
            OVERVIEW_KNOWN_STEPS = "De tu registro de misiones",
            OVERVIEW_NEXT_STEPS = "Siguientes pasos",
            OVERVIEW_NO_KNOWN_STEPS = "No se muestran pasos. Selecciona una misión para ver los detalles.",
            OVERVIEW_UNCERTAIN = "Algunas condiciones o información de las misiones aún no se han verificado.",
            OVERVIEW_SUPPORTING_QUEST = "Misión de apoyo",
            OVERVIEW_MORE_STEPS = "No se muestran aquí otros %d pasos.",
        },
        itIT = {
            OVERVIEW_PREPARATION = "Progressi delle missioni elencate",
            OVERVIEW_STATUS_ACTIVE = "Da consegnare: %d · In corso: %d",
            OVERVIEW_STATUS_RECORDED = "Completate: %d · Incerte: %d",
            OVERVIEW_STATUS_COUNT = "%s: %d",
            OVERVIEW_KNOWN_STEPS = "Dal registro missioni",
            OVERVIEW_NEXT_STEPS = "Prossimi passi",
            OVERVIEW_NO_KNOWN_STEPS = "Non sono elencati passi. Seleziona una missione per i dettagli.",
            OVERVIEW_UNCERTAIN = "Alcune condizioni o informazioni sulle missioni non sono ancora verificate.",
            OVERVIEW_SUPPORTING_QUEST = "Missione di supporto",
            OVERVIEW_MORE_STEPS = "Altri %d passi non sono mostrati qui.",
        },
        ptBR = {
            OVERVIEW_PREPARATION = "Progresso das missões listadas",
            OVERVIEW_STATUS_ACTIVE = "Para entregar: %d · Em andamento: %d",
            OVERVIEW_STATUS_RECORDED = "Concluídas: %d · Incertas: %d",
            OVERVIEW_STATUS_COUNT = "%s: %d",
            OVERVIEW_KNOWN_STEPS = "Do seu registro de missões",
            OVERVIEW_NEXT_STEPS = "Próximas etapas",
            OVERVIEW_NO_KNOWN_STEPS = "Nenhuma etapa listada. Selecione uma missão para ver os detalhes.",
            OVERVIEW_UNCERTAIN = "Algumas condições ou informações das missões ainda não foram verificadas.",
            OVERVIEW_SUPPORTING_QUEST = "Missão de apoio",
            OVERVIEW_MORE_STEPS = "Outras %d etapas não são exibidas aqui.",
        },
        koKR = {
            OVERVIEW_PREPARATION = "목록 퀘스트 진행 상황",
            OVERVIEW_STATUS_ACTIVE = "완료 보고 가능: %d · 진행 중: %d",
            OVERVIEW_STATUS_RECORDED = "완료: %d · 미확인: %d",
            OVERVIEW_STATUS_COUNT = "%s: %d",
            OVERVIEW_KNOWN_STEPS = "퀘스트 목록의 단계",
            OVERVIEW_NEXT_STEPS = "다음 단계",
            OVERVIEW_NO_KNOWN_STEPS = "표시할 단계가 없습니다. 퀘스트를 선택하여 세부 정보를 확인하세요.",
            OVERVIEW_UNCERTAIN = "일부 퀘스트 조건이나 정보가 아직 확인되지 않았습니다.",
            OVERVIEW_SUPPORTING_QUEST = "연계 퀘스트",
            OVERVIEW_MORE_STEPS = "다른 단계 %d개는 여기에 표시되지 않습니다.",
        },
        zhCN = {
            OVERVIEW_PREPARATION = "所列任务进度",
            OVERVIEW_STATUS_ACTIVE = "可交付：%d · 进行中：%d",
            OVERVIEW_STATUS_RECORDED = "已完成：%d · 未确认：%d",
            OVERVIEW_STATUS_COUNT = "%s：%d",
            OVERVIEW_KNOWN_STEPS = "任务日志中的步骤",
            OVERVIEW_NEXT_STEPS = "后续步骤",
            OVERVIEW_NO_KNOWN_STEPS = "没有列出的步骤。选择任务查看详情。",
            OVERVIEW_UNCERTAIN = "部分任务条件或资料尚未核实。",
            OVERVIEW_SUPPORTING_QUEST = "关联任务",
            OVERVIEW_MORE_STEPS = "另有%d个步骤未在此显示。",
        },
        zhTW = {
            OVERVIEW_PREPARATION = "所列任務進度",
            OVERVIEW_STATUS_ACTIVE = "可交付：%d · 進行中：%d",
            OVERVIEW_STATUS_RECORDED = "已完成：%d · 未確認：%d",
            OVERVIEW_STATUS_COUNT = "%s：%d",
            OVERVIEW_KNOWN_STEPS = "任務日誌中的步驟",
            OVERVIEW_NEXT_STEPS = "後續步驟",
            OVERVIEW_NO_KNOWN_STEPS = "沒有列出的步驟。選擇任務查看詳細資訊。",
            OVERVIEW_UNCERTAIN = "部分任務條件或資料尚未核實。",
            OVERVIEW_SUPPORTING_QUEST = "關聯任務",
            OVERVIEW_MORE_STEPS = "另有%d個步驟未在此顯示。",
        },
    }
    for locale, labels in pairs(overviewLabels) do
        for key, value in pairs(labels) do addon.locales[locale][key] = value end
    end
end

for _, locale in ipairs({"deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"}) do
    addon.locales[locale].BACK = addon.locales[locale].DETAIL_BACK
end

local moreLabels = {
    deDE = {"Mehr anzeigen (%d)","Weniger anzeigen"},
    frFR = {"Afficher plus (%d)","Afficher moins"},
    esES = {"Mostrar más (%d)","Mostrar menos"},
    itIT = {"Mostra altri (%d)","Mostra meno"},
    ptBR = {"Mostrar mais (%d)","Mostrar menos"},
    koKR = {"더 보기 (%d)","간략히 보기"},
    zhCN = {"显示更多（%d）","收起"},
    zhTW = {"顯示更多（%d）","收起"},
}
for locale,values in pairs(moreLabels) do addon.locales[locale].OVERVIEW_SHOW_MORE=values[1];addon.locales[locale].OVERVIEW_SHOW_FEWER=values[2] end
