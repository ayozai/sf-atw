/**
 * RequalificationController
 *
 * Apex Controller pour la Quick Action de requalification d'opportunités Global_Renewal.
 * Gère 3 branches métier dans une transaction atomique (Savepoint / rollback).
 *
 * Branches :
 *   1. Allotissement Opp  — Opp d'origine → Requalification ;
 *                           N nouvelles Global_Renewal sur le même contrat (bypass VR)
 *
 *   2. Allotissement CC   — Opp d'origine → Requalification ;
 *                           Opps de renouvellement ouvertes sur les contrats d'application → Requalification ;
 *                           Contrats d'application → Réalloti ;
 *                           N nouvelles Global_Renewal sur le contrat cadre
 *
 *   3. Réallocation périmètre — Opp d'origine → Requalification ;
 *                               Opps cochées → 6. Closed Lost ;
 *                               N nouvelles Global_Bid (nouveau périmètre)
 *
 * Bypass VR :
 *   La VR VR_FR_DontCreateNewRebidOpport bloque la création d'une 2e Global_Renewal
 *   ouverte sur le même contrat. Le bypass consiste à positionner
 *   Requalification_Process__c = true sur les nouvelles opportunités au moment de
 *   l'insertion. La VR contient la condition && Requalification_Process__c = false.
 *
 * Atomicité :
 *   Un Savepoint est posé avant tout DML. En cas d'exception, Database.rollback est
 *   appelé et une AuraHandledException est levée vers le LWC.
 */
public with sharing class RequalificationController {

    // ─── Constantes ───────────────────────────────────────────────────────────

    @TestVisible private static final String STAGE_REQUALIFICATION     = 'Requalification';
    @TestVisible private static final String STAGE_PROSPECT            = '2. Prospect';
    @TestVisible private static final String STAGE_CLOSED_LOST         = '6. Closed Lost';
    @TestVisible private static final String SUB_STAGE_FUTURE_OPP      = '2.1 Future Opportunity';
    @TestVisible private static final String SUB_STAGE_ALLOT_OPP       = 'Allotissement Opp';
    @TestVisible private static final String SUB_STAGE_ALLOT_CC        = 'Allotissement CC';
    @TestVisible private static final String SUB_STAGE_REALLOC         = 'Réallocation périmètre';
    @TestVisible private static final String RT_GLOBAL_RENEWAL         = 'Global_Renewal';
    @TestVisible private static final String RT_GLOBAL_BID             = 'Global_Bid';
    @TestVisible private static final String CONTRACT_STATUS_REALLOCATED = 'Réalloti';

    public class RequalificationException extends Exception {}

    // ─── DTOs ─────────────────────────────────────────────────────────────────

    /** Représente une opportunité à créer, saisie par l'utilisateur dans le LWC. */
    public class OppInput {
        @AuraEnabled public String name;
        @AuraEnabled public String closeDate;   // format ISO 'YYYY-MM-DD'
        @AuraEnabled public String contractId;  // Allotissement CC uniquement
    }

    /** Paramètres envoyés par le LWC à executeRequalification. */
    public class RequalificationRequest {
        @AuraEnabled public String         originOppId;
        @AuraEnabled public String         subStage;
        @AuraEnabled public List<OppInput> newOpportunities;
        @AuraEnabled public List<String>   oppIdsToClose;   // Réallocation uniquement
    }

    /** Option de picklist renvoyée au LWC (contrats, opps). */
    public class PicklistOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    /** Contexte chargé par le LWC au démarrage. */
    public class OpportunityContext {
        @AuraEnabled public String              originOppId;
        @AuraEnabled public String              originOppName;
        @AuraEnabled public String              contractId;
        @AuraEnabled public List<PicklistOption> openRenewalOpps;       // Réallocation
        @AuraEnabled public List<PicklistOption> applicationContracts;  // Allotissement CC
    }

    // ─── Méthodes AuraEnabled ─────────────────────────────────────────────────

    /**
     * Charge le contexte de l'opportunité d'origine pour le LWC.
     * Retourne : champs de l'opp + opps ouvertes sur le même contrat (Réallocation)
     *            + contrats d'application du contrat cadre (Allotissement CC).
     */
    @AuraEnabled(cacheable=true)
    public static OpportunityContext getOpportunityContext(Id originOppId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Contract_Custom__c,
                   OwnerId, Global_Primary_Service__c, CurrencyIsoCode,
                   RecordType.DeveloperName
            FROM   Opportunity
            WHERE  Id = :originOppId
            LIMIT  1
        ];

        if (opp.RecordType.DeveloperName != RT_GLOBAL_RENEWAL) {
            throw new RequalificationException(
                'Cette action n\'est disponible que sur les opportunités Global_Renewal.'
            );
        }

        OpportunityContext ctx    = new OpportunityContext();
        ctx.originOppId           = opp.Id;
        ctx.originOppName         = opp.Name;
        ctx.contractId            = opp.Contract_Custom__c;
        ctx.openRenewalOpps       = new List<PicklistOption>();
        ctx.applicationContracts  = new List<PicklistOption>();

        // Autres opps ouvertes Global_Renewal sur le même contrat (checklist Réallocation)
        for (Opportunity o : [
            SELECT Id, Name
            FROM   Opportunity
            WHERE  Contract_Custom__c        = :opp.Contract_Custom__c
              AND  Id                        != :originOppId
              AND  IsClosed                  = false
              AND  RecordType.DeveloperName  = :RT_GLOBAL_RENEWAL
            ORDER BY Name
        ]) {
            ctx.openRenewalOpps.add(toOption(o.Id, o.Name));
        }

        // Contrats d'application du contrat cadre (Allotissement CC)
        for (Contract__c c : [
            SELECT Id, Name
            FROM   Contract__c
            WHERE  Parent_Contract__c = :opp.Contract_Custom__c
              AND  Status__c          = 'Active'
            ORDER BY Name
        ]) {
            ctx.applicationContracts.add(toOption(c.Id, c.Name));
        }

        return ctx;
    }

    /**
     * Point d'entrée principal — exécute la requalification dans une transaction atomique.
     * Déclenche la branche correspondant à request.subStage.
     */
    @AuraEnabled
    public static void executeRequalification(RequalificationRequest request) {
        if (request == null || String.isBlank(request.originOppId)) {
            throw new AuraHandledException('Paramètres manquants.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (SUB_STAGE_ALLOT_OPP.equals(request.subStage)) {
                executeAllotissementOpp(request);
            } else if (SUB_STAGE_ALLOT_CC.equals(request.subStage)) {
                executeAllotissementCC(request);
            } else if (SUB_STAGE_REALLOC.equals(request.subStage)) {
                executeReallocation(request);
            } else {
                throw new RequalificationException(
                    'Type de requalification inconnu : ' + request.subStage
                );
            }
        } catch (AuraHandledException ahe) {
            Database.rollback(sp);
            throw ahe;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── Branches ─────────────────────────────────────────────────────────────

    /**
     * Allotissement Opp :
     *  1. Opp d'origine → Requalification / Allotissement Opp
     *  2. N nouvelles Global_Renewal sur le même contrat (Requalification_Process__c = true)
     */
    private static void executeAllotissementOpp(RequalificationRequest req) {
        validateNewOpps(req.newOpportunities);

        Opportunity origin = loadOriginOpp(req.originOppId);
        Id rtId = getRecordTypeId(RT_GLOBAL_RENEWAL);

        origin.StageName    = STAGE_REQUALIFICATION;
        origin.Sub_Stage__c = SUB_STAGE_ALLOT_OPP;

        List<Opportunity> newOpps = buildNewOpps(
            req.newOpportunities, origin, rtId, origin.Contract_Custom__c
        );

        update origin;
        insert newOpps;
    }

    /**
     * Allotissement CC :
     *  1. Opp d'origine → Requalification / Allotissement CC
     *  2. Opps de renouvellement ouvertes sur les contrats d'application → Requalification / Allotissement CC
     *  3. Contrats d'application → Réalloti
     *  4. N nouvelles Global_Renewal sur les contrats d'application (un Contract__c par opp)
     */
    private static void executeAllotissementCC(RequalificationRequest req) {
        validateNewOpps(req.newOpportunities);

        Opportunity origin        = loadOriginOpp(req.originOppId);
        Id          frameworkId   = origin.Contract_Custom__c;
        Id          rtId          = getRecordTypeId(RT_GLOBAL_RENEWAL);

        // Tous les contrats d'application du contrat cadre
        List<Contract__c> appContracts = [
            SELECT Id, Status__c
            FROM   Contract__c
            WHERE  Parent_Contract__c = :frameworkId
        ];
        Set<Id> appContractIds = new Map<Id, Contract__c>(appContracts).keySet();

        // Opps de renouvellement ouvertes sur les contrats d'application
        List<Opportunity> childOpps = [
            SELECT Id, StageName, Sub_Stage__c
            FROM   Opportunity
            WHERE  Contract_Custom__c       IN :appContractIds
              AND  IsClosed                 = false
              AND  RecordType.DeveloperName = :RT_GLOBAL_RENEWAL
              AND  Id                       != :origin.Id
        ];

        // Fermer l'opp d'origine
        origin.StageName    = STAGE_REQUALIFICATION;
        origin.Sub_Stage__c = SUB_STAGE_ALLOT_CC;

        // Fermer les opps enfants
        for (Opportunity o : childOpps) {
            o.StageName    = STAGE_REQUALIFICATION;
            o.Sub_Stage__c = SUB_STAGE_ALLOT_CC;
        }

        // Réallotir les contrats d'application
        for (Contract__c c : appContracts) {
            c.Status__c = CONTRACT_STATUS_REALLOCATED;
        }

        // Nouvelles opps — chaque opp est rattachée au contrat sélectionné par l'utilisateur
        // (ou au contrat cadre par défaut si aucun n'est précisé)
        List<Opportunity> newOpps = new List<Opportunity>();
        for (OppInput oi : req.newOpportunities) {
            Id contractId = String.isNotBlank(oi.contractId)
                ? (Id) oi.contractId
                : frameworkId;
            newOpps.add(buildNewOpp(oi, origin, rtId, contractId));
        }

        update origin;
        if (!childOpps.isEmpty())    { update childOpps; }
        if (!appContracts.isEmpty()) { update appContracts; }
        insert newOpps;
    }

    /**
     * Réallocation périmètre :
     *  1. Opp d'origine → Requalification / Réallocation périmètre
     *  2. Opps cochées → 6. Closed Lost
     *  3. N nouvelles Global_Bid (nouveau périmètre à conquérir)
     */
    private static void executeReallocation(RequalificationRequest req) {
        Opportunity origin = loadOriginOpp(req.originOppId);
        Id rtBidId = getRecordTypeId(RT_GLOBAL_BID);

        origin.StageName    = STAGE_REQUALIFICATION;
        origin.Sub_Stage__c = SUB_STAGE_REALLOC;

        // Fermer les opps cochées en Perdu
        List<Opportunity> oppsToClose = new List<Opportunity>();
        if (req.oppIdsToClose != null && !req.oppIdsToClose.isEmpty()) {
            Set<Id> idsToClose = new Set<Id>();
            for (String s : req.oppIdsToClose) { idsToClose.add((Id) s); }
            oppsToClose = [
                SELECT Id
                FROM   Opportunity
                WHERE  Id        IN :idsToClose
                  AND  IsClosed  = false
            ];
            for (Opportunity o : oppsToClose) {
                o.StageName = STAGE_CLOSED_LOST;
            }
        }

        // Nouvelles opps de développement Global_Bid
        List<Opportunity> newOpps = new List<Opportunity>();
        if (req.newOpportunities != null && !req.newOpportunities.isEmpty()) {
            newOpps = buildNewOpps(
                req.newOpportunities, origin, rtBidId, origin.Contract_Custom__c
            );
        }

        update origin;
        if (!oppsToClose.isEmpty()) { update oppsToClose; }
        if (!newOpps.isEmpty())     { insert newOpps; }
    }

    // ─── Helpers privés ───────────────────────────────────────────────────────

    private static Opportunity loadOriginOpp(Id oppId) {
        return [
            SELECT Id, Name, AccountId, Contract_Custom__c, OwnerId,
                   Global_Primary_Service__c, CurrencyIsoCode, RecordTypeId
            FROM   Opportunity
            WHERE  Id = :oppId
            LIMIT  1
        ];
    }

    private static List<Opportunity> buildNewOpps(
        List<OppInput> inputs,
        Opportunity    origin,
        Id             recordTypeId,
        Id             defaultContractId)
    {
        List<Opportunity> opps = new List<Opportunity>();
        for (OppInput oi : inputs) {
            opps.add(buildNewOpp(oi, origin, recordTypeId, defaultContractId));
        }
        return opps;
    }

    private static Opportunity buildNewOpp(
        OppInput    oi,
        Opportunity origin,
        Id          recordTypeId,
        Id          contractId)
    {
        Opportunity opp = new Opportunity();
        opp.Name                       = oi.name;
        opp.CloseDate                  = Date.valueOf(oi.closeDate);
        opp.StageName                  = STAGE_PROSPECT;
        opp.Sub_Stage__c               = SUB_STAGE_FUTURE_OPP;
        opp.AccountId                  = origin.AccountId;
        opp.Contract_Custom__c         = contractId;
        opp.OwnerId                    = origin.OwnerId;
        opp.RecordTypeId               = recordTypeId;
        opp.Global_Primary_Service__c  = origin.Global_Primary_Service__c;
        opp.CurrencyIsoCode            = origin.CurrencyIsoCode;
        opp.Requalification_Process__c = true;  // bypass VR_FR_DontCreateNewRebidOpport
        return opp;
    }

    private static Id getRecordTypeId(String developerName) {
        Schema.RecordTypeInfo rt = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get(developerName);
        if (rt == null || !rt.isAvailable()) {
            throw new RequalificationException(
                'RecordType Opportunity introuvable : ' + developerName
            );
        }
        return rt.getRecordTypeId();
    }

    private static PicklistOption toOption(String value, String label) {
        PicklistOption o = new PicklistOption();
        o.value = value;
        o.label = label;
        return o;
    }

    private static void validateNewOpps(List<OppInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            throw new RequalificationException('Au moins une opportunité à créer est requise.');
        }
        for (OppInput oi : inputs) {
            if (String.isBlank(oi.name)) {
                throw new RequalificationException('Le nom de chaque opportunité est obligatoire.');
            }
            if (String.isBlank(oi.closeDate)) {
                throw new RequalificationException('La date de clôture de chaque opportunité est obligatoire.');
            }
        }
    }
}
