Je vous conseille de commencer par deux changements courts, puis d'attendre avant le reste.

1. Le cycle par famille, tout de suite
C'est le meilleur rapport effort/gain : environ une demi-journée de travail, sur player_controller, le HUD et l'aide.
- N fait tourner grenade → fumigène → assourdissante.
- ù fait tourner obus explosif → fumigène → lacrymogène.
- On libère ainsi « ; », Maj+N, Maj+; et Maj+ù.
- Un nouveau type de grenade ou d'obus ne demandera plus de touche.

Pour le second appui, je propose qu'il fasse tourner en boucle, en sautant les types que l'équipe n'a plus. On annule par Échap ou le clic droit, comme aujourd'hui. Désarmer après le dernier type serait déroutant : on ne sait jamais si le prochain appui arme ou annule. La touche arme d'abord le dernier type utilisé, qu'on retrouve donc d'un seul appui.

2. Les menus sur les touches de fonction, en même temps
Aide sur F1, objectifs sur F2, minicarte sur F3. C'est presque gratuit (trois lignes dans project.godot, puis le README et l'aide en jeu) et ça libère H, O et M. Je n'y mettrais rien tout de suite : ce sont des réserves pour les prochains ajouts, que vous aurez sans toucher aux habitudes actuelles.

3. Ensuite, attendre
- Emplacements 7 à 0 : seulement si de nouveaux objets rares arrivent. Sinon, le seul gain est de sortir le Taser de Maj+B, ce qui ne presse pas.
- Roue d'équipement : à garder pour plus tard. Elle n'est utile que si l'équipement double encore, et c'est un vrai chantier d'interface.
- Écran de configuration des touches : à faire une fois les touches stabilisées, sinon on le refait à chaque changement. C'est aussi le moment de régler le point 5.10 (touches écrites en dur dans les libellés).
- Touche contextuelle : à garder pour un futur travail sur les ordres ; c'est un changement de prise en main plus qu'une question de clavier.

Voulez-vous que j'implémente les points 1 et 2, en un commit chacun ?
