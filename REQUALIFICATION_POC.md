# Requalification d'opportunités de renouvellement — POC

**Ticket Jira** : IACRM-389
**Branche** : `feature/IACRM-389-opportunity-renouvellement`
**Spec source** : SoW_Requalification_POC_20260908 (Mahdi) / Spec_metier_renouvellement V10 (Alexandra Petrissans)

---

## Contexte

La VR `VR_FR_DontCreateNewRebidOpport` bloque la coexistence de plusieurs opportunités de renouvellement ouvertes sur un même contrat, même dans les cas légitimes d'allotissements multiples. Ce POC ajoute un mécanisme officiel de requalification via une Quick Action sur les opportunités `Global_Renewal`.

---

## Composants créés / modifiés

### Métadonnées

| Fichier | Modification |
|---|---|
| `standardValueSets/OpportunityStage.standardValueSet-meta.xml` | Ajout valeur `Requalification` (IsClosed=true, ForecastCategory=Omitted) |
| `objects/Opportunity/fields/Sub_Stage__c.field-meta.xml` | Ajout valeurs : `Allotissement Opp`, `Allotissement CC`, `Réallocation périmètre` |
| `objects/Opportunity/fields/Requalification_Process__c.field-meta.xml` | **Nouveau** champ Checkbox technique (bypass VR) |
| `objects/Opportunity/validationRules/VR_FR_DontCreateNewRebidOpport.validationRule-meta.xml` | Ajout condition `&& Requalification_Process__c = false` |
| `objects/Contract__c/fields/Status__c.field-meta.xml` | Ajout valeur `Réalloti` |
| `labels/CustomLabels.labels-meta.xml` | 18 labels custom catégorie `Requalification` |
| `quickActions/Opportunity.Requalification.quickAction-meta.xml` | **Nouveau** Quick Action LWC sur Opportunity |

### Apex

| Classe | Rôle |
|---|---|
| `classes/RequalificationController.cls` | Controller principal — 3 branches, bypass VR, transaction atomique |
| `classes/RequalificationController_Test.cls` | Tests unitaires (11 méthodes, cible ≥ 85 %) |

### LWC

| Composant | Rôle |
|---|---|
| `lwc/requalificationWizard` | Wizard 3 écrans : choix branche → formulaire → récapitulatif |

---

## Architecture

```
Quick Action (Opportunity.Requalification)
    └── LWC : requalificationWizard
            ├── Écran 1 — Choix de la branche (radio group)
            ├── Écran 2 — Formulaire dynamique (conditionnel par branche)
            └── Écran 3 — Récapitulatif + confirmation
                    └── @AuraEnabled RequalificationController.executeRequalification()
                            ├── Branche Allotissement Opp
                            ├── Branche Allotissement CC
                            └── Branche Réallocation périmètre
```

---

## Logique métier par branche

### Allotissement Opp
1. Opp d'origine → `Requalification` / `Allotissement Opp`
2. N nouvelles `Global_Renewal` créées sur le même contrat avec `Requalification_Process__c = true` (bypass VR)
3. Nouvelles opps → `2. Prospect` / `2.1 Future Opportunity`

### Allotissement CC
1. Opp d'origine → `Requalification` / `Allotissement CC`
2. Toutes les opps `Global_Renewal` ouvertes sur les contrats d'application → `Requalification` / `Allotissement CC`
3. Contrats d'application → `Réalloti`
4. N nouvelles `Global_Renewal` créées (une par contrat sélectionné par l'utilisateur)

### Réallocation périmètre
1. Opp d'origine → `Requalification` / `Réallocation périmètre`
2. Opps cochées → `6. Closed Lost`
3. N nouvelles `Global_Bid` créées (nouveau périmètre)

---

## Bypass VR

La VR `VR_FR_DontCreateNewRebidOpport` contient la condition :
```
&& Requalification_Process__c = false
```
Le champ `Requalification_Process__c` (Checkbox, défaut `false`) est positionné à `true` uniquement par `RequalificationController` au moment de l'insertion des nouvelles opportunités. La création manuelle reste bloquée.

---

## Champs hérités de l'opp d'origine

Toutes les nouvelles opps héritent automatiquement :
- `AccountId`
- `Contract_Custom__c` (sauf Allotissement CC : contrat sélectionné par l'utilisateur)
- `OwnerId`
- `RecordTypeId`
- `Global_Primary_Service__c`
- `CurrencyIsoCode`

---

## Dynamic Action — configuration manuelle (App Builder)

La Quick Action est déployée via SFDX. La restriction à `RecordType = Global_Renewal` se configure manuellement dans le Lightning App Builder :

1. Setup → Object Manager → **Opportunity** → Lightning Record Pages → page active
2. Highlights Panel → ajouter l'action **Requalification**
3. Cliquer sur l'action → **Add Filter** → `Record Type Developer Name` `Equals` `Global_Renewal`
4. Sauvegarder et activer

---

## Déploiement

```bash
# Déployer sur la sandbox INTEG
sf project deploy start --target-org <alias-integ> --manifest manifest/package.xml

# Lancer les tests Apex
sf apex run test --class-names RequalificationController_Test --target-org <alias-integ> --result-format human

# Ouvrir l'org
sf org open --target-org <alias-integ>
```

---

## Points ouverts (à valider avec Alexandra Petrissans)

| # | Point | Impact |
|---|---|---|
| 1 | Conditions de visibilité du bouton (stages autorisés) | Dynamic Action filter |
| 2 | Restriction par profil/rôle (DA, KAM, tous ?) | Dynamic Action / Permission Set |
| 3 | Valeurs Sub_Stage__c exactes (libellés FR) | Picklist |
| 4 | ForecastCategory `Omitted` pour `Requalification` | Reporting |
| 5 | Rattachement chantiers ↔ opps (exclu, prévu T4 2026) | Hors périmètre |

---

## Exclusions du périmètre POC

- Rattachement chantiers ↔ opportunités (projet distinct T4 2026)
- Mise à jour directe des contrats d'origine (toujours via opportunité)
