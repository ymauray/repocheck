# Cahier des charges — agent auditeur

> **Statut : proposition à évaluer.** Ce document décrit un agent IA capable de
> mener un audit de dépôt de bout en bout. Il n'est pas adopté : il existe pour
> être confronté à `github-audits-reference.csv` et comparé au mode `-Audit`.
> Voir « Protocole d'évaluation » en fin de document.

## 1. Pourquoi

Le mode `-Audit` couvre 29 des 35 pratiques du catalogue. Les 6 restantes et les
18 divergences observées ont toutes la même nature : **elles demandent un
jugement, pas une lecture d'API.**

| Ce qui manque au script | Exemples |
|---|---|
| Juger un contenu | META-04 (README complet), META-06 (`.gitignore` adapté), META-09 (chaîne CI/CD documentée) |
| Juger qu'une pratique est sans objet | les 12 `NA` de `ymauray/ymauray`, les `NA` Dependabot des dépôts de distribution |
| Tenir compte d'un outil invisible via l'API | CI-01 et CI-05 sur les dépôts livrés par Xcode Cloud |

Un agent lit le catalogue en prose et raisonne dessus. Il n'a pas besoin qu'on
traduise chaque pratique en code, et le catalogue redevient l'unique source de
vérité au lieu d'être dupliqué dans PowerShell.

## 2. Ce que l'agent reçoit

- **`github-bonnes-pratiques.md`** — le catalogue. Fait autorité : l'agent ne le
  modifie jamais et ne réinterprète pas une pratique dont le libellé lui semble
  imprécis. Il signale l'imprécision plutôt que de la trancher seul.
- **`CLAUDE.md`** — la méthodologie et les pièges connus de l'API.
- **La cible** — un `owner/repo`.
- **`gh`, authentifié** — en lecture seule. L'agent n'écrit jamais dans le dépôt
  audité.

Il ne reçoit **pas** `github-audits-reference.csv`, ni les rapports existants,
ni les notes d'un audit antérieur du même dépôt. Un audit part des faits.

## 3. Ce que l'agent produit

Pour chaque pratique du catalogue :

- un **statut** : `OK`, `KO` ou `NA` ;
- une **note** lorsque le statut n'est pas évident, au format `ID: explication`,
  factuelle et vérifiable.

Plus, séparément, les **entrées `.repocheckignore` proposées** : chaque `NA`
relevant d'un jugement de contexte, avec sa justification. C'est ce qui fige le
raisonnement dans un artefact relisible et corrigeable, au lieu de le laisser
se rejouer différemment à chaque exécution.

## 4. Comment décider

### 4.1 La règle générale

`OK` la pratique est respectée · `KO` elle ne l'est pas · `NA` **elle n'a pas
d'objet dans ce dépôt**.

### 4.2 Le test décisif du `NA`

Trois questions, **dans cet ordre**. L'ordre est tout : la même pratique change
de statut selon la question qu'on pose en premier.

**1. La pratique porte-t-elle sur quelque chose qui existe dans ce dépôt ?**
Si non → `NA`, et on s'arrête là.

C'est la question de l'**objet**. Un dépôt sans aucun workflow ne peut pas y
déclarer de bloc `permissions:` : CI-03 n'a pas d'objet. Un dépôt sans aucun tag
n'a aucune cohérence de tags à évaluer : CI-06 n'a pas d'objet.

Attention au piège de la vacuité : « tous les workflows déclarent leurs
permissions » est *techniquement vrai* quand il n'y a aucun workflow. Ce n'est
pas pour autant une conformité — c'est une absence d'objet.

**2. Est-elle respectée ?** Si oui → `OK`.

C'est la question de la **conformité**, et elle ne se pose que si l'objet existe.
Un dépôt qui a des workflows et n'y utilise aucune action tierce **respecte**
CI-04 : l'objet existe — des actions —, et aucune n'est laissée sur un tag
mouvant. Il n'en est pas dispensé.

**3. Sinon → `KO`,** sauf si l'appliquer ne produirait aucun effet, auquel cas
`NA`.

Activer Dependabot alerts sur `homebrew-tap` : le réglage existe bien, mais
aucun manifest reconnu par Dependabot n'est présent, l'activation ne produirait
rien → `NA`. Activer le secret scanning sur un dépôt de profil : ça marche et ça
sert → `KO`.

### 4.3 Trois `NA` interdits

1. **`NA` parce que l'information est indisponible.** Un dépôt privé en plan
   gratuit répond `403` sur la protection de branche et `null` sur
   `security_and_analysis`. La convention du catalogue est `KO` : publier le
   dépôt suffit à rendre la fonctionnalité disponible gratuitement, l'écart est
   réel. La note doit dire que la cause est l'indisponibilité.
2. **`NA` parce que c'est difficile à évaluer.** Un doute se résout en
   cherchant, ou se signale explicitement — il ne se convertit pas en `NA`.
3. **`NA` par confort.** Les `NA` sont exclus du score : en poser un à tort
   améliore mécaniquement la note. C'est l'erreur la plus coûteuse de tout
   l'exercice, et elle est silencieuse.

### 4.4 Justifier un `NA`

La note d'un `NA` dit **pourquoi la pratique est sans objet**, jamais pourquoi
elle n'est pas respectée.

- ✅ « CI-06: N/A, aucun tag à évaluer »
- ✅ « SEC-01: N/A, ni les formules Homebrew ni les manifests Scoop ne sont des
  écosystèmes reconnus par Dependabot »
- ❌ « SEC-01: N/A, les alertes ne sont pas activées » — ça, c'est un `KO`.

### 4.5 Typologie observée

Le type de dépôt conditionne une grande partie des `NA`. Quatre profils sont
apparus sur les 14 dépôts audités à la main :

| Profil | Reconnaissance | Conséquence |
|---|---|---|
| Application ou outil livré | code applicatif, dépendances, releases | tout le catalogue s'applique |
| Cible de distribution | manifests d'installation (`Formula/*.rb`, `*.json` Scoop), commits d'un bot | pas d'écosystème Dependabot, pas de release propre |
| Dépôt de profil | nom identique au propriétaire, README seul | ni code à licencier, ni public à orienter, ni contribution |
| Site ou documentation | contenu publié, pas de build applicatif | CI et releases souvent sans objet |

Cette liste est indicative, **pas limitative**. Un profil non listé se traite
au cas par cas, avec le test de 4.2.

## 5. Garde-fous

- **Ne rien inventer.** Un statut s'appuie sur une observation. En cas de doute
  irréductible, le dire dans la note plutôt que de trancher au hasard.
- **Ne pas surinterpréter l'absence.** Aucun workflow GitHub Actions ne signifie
  pas « aucune CI » : `nannyplus`, `DuoScribo` et `FeuilleBlanche` recourent à
  des outils externes invisibles via l'API. Signaler l'incertitude.
- **Ne pas modifier le dépôt audité**, ni le catalogue, ni la référence.
- **Ne pas corriger les écarts relevés.** Auditer n'est pas réparer.
- **Préférer un `KO` argumenté à un `NA` commode.**

## 6. Protocole d'évaluation

L'agent se mesure exactement comme le script, avec le même instrument :

```
./tests/Compare-Reference.ps1 -CandidatePath <csv-produit-par-l-agent>
```

Conditions pour que le résultat veuille dire quelque chose :

1. **L'agent ne doit pas connaître la référence.** Une instance qui a participé
   à sa construction ne peut pas s'auto-évaluer : elle a les réponses. Le test
   demande une exécution à froid.
2. **Seuls les statuts sont comparés**, jamais les notes.
3. **Trois chiffres à relever** : pratiques conformes sur 35 ; divergences
   restantes ; et surtout **`NA` posés à tort**, qui sont l'erreur coûteuse.

### Ce qui a été mesuré

Six exécutions à froid, dans des worktrees git isolés — la référence et les
rapports étant ignorés par git, ils n'existent pas dans l'environnement de
l'agent : l'isolation ne repose sur aucune promesse.

| Dépôt | Exécutions | Stabilité entre elles | Écart de score |
|---|---|---|---|
| `homebrew-tap` | 2 | 33/35 | 1 point (20 % / 19 %) |
| `clepsydre`, documents imprécis | 2 | 33/35 | **8 points** (19 % / 27 %) |
| `clepsydre`, documents corrigés | 2 | **35/35** | **0** |

Réponses aux quatre questions :

1. **Les 29 pratiques déterministes** — aucune divergence sur aucune d'elles, sur
   les six exécutions. Il n'y a rien à gagner à déléguer à un agent ce que le
   script établit déjà par lecture d'API.
2. **Les `NA` de contexte** — retrouvés, et l'exercice a fait mieux que les
   retrouver : il a révélé **trois `NA` fautifs de la référence**, dont deux
   violaient la règle des `NA` interdits énoncée plus haut.
3. **Les 6 pratiques hors périmètre du script** — toutes traitées correctement.
   C'est là que l'agent complète réellement le script, plutôt que de le doubler.
4. **La reproductibilité** — 33/35 avec des documents imprécis, **35/35 après
   les avoir précisés**, sans rien changer à l'agent.

### Deux enseignements

**Le taux de stabilité ne veut rien dire seul.** Les deux premières expériences
donnent le même 33/35, pour un écart de score de 1 point puis de 8. Ce qui
compte est la **criticité** des cellules instables : une 🔴 pèse quatre fois une
⚪. C'est cette mesure-là qu'il faut suivre.

**L'instabilité n'est pas une propriété de l'agent, c'est un symptôme
d'imprécision du référentiel.** Sur les six exécutions, aucune divergence n'a
été une erreur de raisonnement : chacune a pointé une imprécision du catalogue,
une contradiction entre le catalogue et ce document, ou une erreur de la
référence. Les corriger a supprimé l'instabilité.

Le corollaire est important : ce que le mode `-Audit` a apporté n'est pas
seulement 29 règles automatisées. C'est d'avoir **forcé à expliciter des règles
que quatorze audits manuels laissaient implicites**. Un agent lâché sur un
référentiel flou produit un résultat plausible et instable, sans le signaler ;
écrire le code, lui, ne pardonne rien.
