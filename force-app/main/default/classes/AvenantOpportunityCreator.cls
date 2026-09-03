/**
 * AvenantOpportunityCreator
 *
 * Crée automatiquement une opportunité de type "Avenant" (Amendment) EN STATUT
 * CLÔTURÉE GAGNÉE pour chaque contrat rattaché à un contrat cadre (Framework Agreement).
 *
 * Modèle de données Atalian :
 *   - Un "contrat cadre" est un Contract__c dont Type__c = 'Framework Agreement'
 *     (ou 'Master Service Agreement').
 *   - Les "contrats liés" sont les Contract__c dont Parent_Contract__c pointe vers ce cadre.
 *   - Un "avenant" est une Opportunity :
 *         RecordType                          = Global_Upsell
 *         Global_Business_Type_Opportunity__c = 'Amendment on Existing Account'
 *         StageName                           = '5. Closed Won'
 *         Sub_Stage__c                        = '5.1 Written Confirmation'
 *
 * CRÉATION EN DEUX TEMPS (insert -> update) :
 *   La validation rule Global_Check_Stages_On_Create interdit de créer une opp
 *   directement en statut clôturé à tout profil SAUF exactement 'System Administrator'.
 *   On insère donc d'abord au stade ouvert (OPP_OPEN_STAGE), puis on met à jour en
 *   Closed Won. Cette bascule reflète le vrai changement de statut et contourne la
 *   règle pour tous les profils.
 *
 * VALIDATION RULES DE CLÔTURE (Closed Won) :
 *   - Non applicables à l'avenant (RT Global_Upsell) : Global_Closed_Won_Required_Fields,
 *     Global_Closed_Won_Required_One_Atalian, Won_Oppty_Current_Provider_Required.
 *   - Applicables au niveau champ (couvertes par le mapping) :
 *       Global_Check_SubStage32_Required_Fields -> PaymentTermsDays__c
 *   - Requièrent des enregistrements liés pour les profils NON-admin :
 *       Global_Require_Contact_Roles_On_Close   -> >= 1 OpportunityContactRole
 *       Global_Require_Services_On_Close         -> >= 1 OpportunityLineItem
 *       VR_Opport_CFB_Required                   -> compte validé CFB
 *     >>> Ces règles sont bypassées pour les profils Admin/Controlling. L'automatisation
 *         est donc prévue pour tourner sous un tel profil (choix validé). Tout blocage
 *         résiduel (ex. Controlling + Require_Services) est remonté par contrat via
 *         allOrNone=false, sans bloquer les autres.
 *
 * MISE À JOUR AUTOMATIQUE DU CONTRAT (extension) :
 *   Lorsqu'un avenant Global_Upsell passe Closed Won, le flow de production existant
 *   "Opportunity RTF - Global Upsell Closed Won" recopie sur le contrat lié :
 *       Contract__c.Contract_End_Date__c <- Opportunity.Contract_End_Date__c
 *       (uniquement si la date de l'opp diffère de celle du contrat)
 *   Ce code renseigne donc Opportunity.Contract_End_Date__c = date de fin actuelle
 *   du contrat + extensionMonths, pour que le contrat soit effectivement prolongé.
 *   Si extensionMonths est null/0, l'opp reprend la date de fin ACTUELLE du contrat :
 *   le flow ne détecte alors aucun changement et ne modifie pas le contrat.
 *
 * Un garde-fou (validateRequiredFields) vérifie AVANT insertion, via l'API Schema,
 * que tous les champs universellement obligatoires de l'Opportunity sont renseignés.
 *
 * Usage (Apex anonyme / Dev Console) :
 *   // Prolonger chaque contrat lié de 12 mois :
 *   AvenantOpportunityCreator.Outcome o =
 *       AvenantOpportunityCreator.createForFrameworkContract('a0X...', 12);
 *   System.debug(o.summary());
 */
public with sharing class AvenantOpportunityCreator
{
    /** Exception métier (paramètres invalides, contrat cadre introuvable, etc.). */
    public class AvenantException extends Exception {}

    // ----------------------------------------------------------------------
    // Paramètres configurables
    // ----------------------------------------------------------------------

    /** DeveloperName du record type Opportunity pour un avenant. */
    private static final String OPP_RECORD_TYPE_DEVNAME = 'Global_Upsell';

    /** Stade ouvert utilisé à l'insertion (avant bascule en Closed Won). */
    private static final String OPP_OPEN_STAGE = '2. Prospect';

    /** Stade et sous-stade finaux : clôturée gagnée. */
    private static final String OPP_CLOSED_STAGE = '5. Closed Won';
    private static final String OPP_CLOSED_SUB_STAGE = '5.1 Written Confirmation';

    /** Business type identifiant un avenant. */
    private static final String OPP_BUSINESS_TYPE = 'Amendment on Existing Account';

    /** Type de contrat par défaut (repris du flow). */
    private static final String OPP_CONTRACT_TYPE = 'Contractual';

    /**
     * Mapping "champ source Contract__c" -> "champ cible Opportunity", repris du flow
     * de production. Les champs cible inexistants/non créables dans l'org sont ignorés
     * silencieusement (putIfWritable).
     */
    private static final Map<String, String> FIELD_MAP = new Map<String, String>{
        'Account__c'                                => 'AccountId',
        'Primary_Service__c'                        => 'Global_Primary_Service__c',
        'Reference__c'                              => 'Site_Names__c',
        'Active_Accounting_System_Site_Count__c'    => 'Number_of_Sites__c',
        'Payment_Terms__c'                          => 'PaymentTermsDays__c',
        'Public_Private_Market__c'                  => 'Public_Private_Market__c',
        'Tier_2_Account__c'                         => 'Tier_2_Account__c',
        'Contract_Market_Segment__c'                => 'Market_Segment__c',
        'Department_FR_Contract__c'                 => 'Department_FR__c',
        'Region_FR__c'                              => 'Region_FR__c',
        'Effective_Annual_Revenue__c'               => 'Amount',
        'Accounting_System_Site_Annual_Revenue__c'  => 'Ongoing_Current_contract_revenue__c'
    };

    // ----------------------------------------------------------------------
    // Résultat
    // ----------------------------------------------------------------------

    public class Outcome
    {
        /** Avenants effectivement clôturés gagnés. */
        public List<Opportunity> created = new List<Opportunity>();
        /** Contrats ignorés volontairement (ex. expirés), avec le motif. */
        public List<String> skipped = new List<String>();
        /** Échecs (insertion ou bascule Closed Won), avec le contrat concerné. */
        public List<String> errors = new List<String>();

        public String summary()
        {
            String s = created.size() + ' avenant(s) créé(s) en Closed Won.';
            if (!skipped.isEmpty())
            {
                s += '\n' + skipped.size() + ' contrat(s) ignoré(s) :\n - ' + String.join(skipped, '\n - ');
            }
            if (!errors.isEmpty())
            {
                s += '\n' + errors.size() + ' échec(s) :\n - ' + String.join(errors, '\n - ');
            }
            return s;
        }
    }

    // ----------------------------------------------------------------------
    // Point d'entrée principal
    // ----------------------------------------------------------------------

    /** Surcharge sans extension : ne modifie pas la date de fin des contrats. */
    public static Outcome createForFrameworkContract(Id frameworkContractId)
    {
        return createForFrameworkContract(frameworkContractId, null);
    }

    /**
     * Crée un avenant clôturé gagné pour chaque contrat rattaché au contrat cadre fourni.
     *
     * @param frameworkContractId Id du contrat cadre (Contract__c, Type = Framework/MSA)
     * @param extensionMonths     Nombre de mois d'extension ajouté à la date de fin
     *                            actuelle de chaque contrat lié (null/0 = pas d'extension)
     * @return Outcome : avenants clôturés + éventuels échecs détaillés
     */
    public static Outcome createForFrameworkContract(Id frameworkContractId, Integer extensionMonths)
    {
        if (frameworkContractId == null)
        {
            throw new AvenantException('L\'Id du contrat cadre est obligatoire.');
        }

        Contract__c framework = loadFramework(frameworkContractId);
        List<Contract__c> children = loadChildContracts(frameworkContractId);
        if (children.isEmpty())
        {
            throw new AvenantException(
                'Aucun contrat rattaché au contrat cadre ' + framework.Name +
                ' (' + frameworkContractId + ') via Parent_Contract__c.'
            );
        }
        return processChildContracts(children, extensionMonths);
    }

    /**
     * Cœur du traitement, réutilisable en synchrone et par le batch : construit les
     * avenants (en ignorant les contrats expirés), insère au stade ouvert, puis
     * bascule en Closed Won. Tolérant aux erreurs (allOrNone=false) : chaque échec
     * est rapporté par contrat sans bloquer les autres.
     *
     * @param children        Contrats liés à traiter (déjà chargés avec les champs requis)
     * @param extensionMonths Mois d'extension ajoutés à la date de fin (null/0 = aucun)
     */
    public static Outcome processChildContracts(List<Contract__c> children, Integer extensionMonths)
    {
        Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
        Id recordTypeId = resolveRecordTypeId();

        Outcome outcome = new Outcome();

        // Étape 1 : construire les opportunités au stade OUVERT, en ignorant les
        // contrats dont la nouvelle date de fin serait nulle ou déjà passée.
        // (Le flow before-save Opportunity_Automation force contract_start_date__c =
        //  CloseDate = aujourd'hui ; une date de fin passée violerait la VR fin >= début
        //  et le flow de clôture blanchirait la date de fin du contrat.)
        List<Opportunity> avenants = new List<Opportunity>();
        Map<Integer, Contract__c> indexToContract = new Map<Integer, Contract__c>();
        for (Contract__c child : children)
        {
            String skipReason = extensionSkipReason(child, extensionMonths);
            if (skipReason != null)
            {
                outcome.skipped.add('Contrat ' + child.Name + ' : ' + skipReason);
                continue;
            }
            indexToContract.put(avenants.size(), child);
            avenants.add(buildAvenant(child, oppFields, recordTypeId, extensionMonths));
        }

        if (avenants.isEmpty())
        {
            return outcome;   // tout a été ignoré : rien à insérer
        }

        // Garde-fou : champs universellement obligatoires renseignés ?
        validateRequiredFields(avenants, indexToContract, oppFields);

        // Étape 2 : insertion (stade ouvert), tolérante aux erreurs.
        List<Opportunity> insertedOk = new List<Opportunity>();
        Map<Integer, Contract__c> insertedIndexToContract = new Map<Integer, Contract__c>();
        List<Database.SaveResult> insertResults = Database.insert(avenants, false);
        for (Integer i = 0; i < insertResults.size(); i++)
        {
            if (insertResults[i].isSuccess())
            {
                insertedIndexToContract.put(insertedOk.size(), indexToContract.get(i));
                insertedOk.add(avenants[i]);
            }
            else
            {
                outcome.errors.add('Contrat ' + indexToContract.get(i).Name +
                    ' (création) : ' + formatErrors(insertResults[i].getErrors()));
            }
        }

        // Étape 3 : bascule en Closed Won.
        if (!insertedOk.isEmpty())
        {
            for (Opportunity opp : insertedOk)
            {
                applyClosedWon(opp, oppFields);
            }
            List<Database.SaveResult> updateResults = Database.update(insertedOk, false);
            for (Integer i = 0; i < updateResults.size(); i++)
            {
                if (updateResults[i].isSuccess())
                {
                    outcome.created.add(insertedOk[i]);
                }
                else
                {
                    outcome.errors.add('Contrat ' + insertedIndexToContract.get(i).Name +
                        ' (clôture Closed Won) : ' + formatErrors(updateResults[i].getErrors()) +
                        ' [opportunité ' + insertedOk[i].Id + ' laissée au stade ouvert]');
                }
            }
        }

        return outcome;
    }

    // ----------------------------------------------------------------------
    // Méthode invocable (Flow / bouton)
    // ----------------------------------------------------------------------

    @InvocableMethod(label='Créer les avenants (Closed Won) pour un contrat cadre'
                     description='Crée un avenant clôturé gagné par contrat lié au contrat cadre fourni.')
    public static List<Result> createAvenants(List<Request> requests)
    {
        List<Result> results = new List<Result>();
        for (Request req : requests)
        {
            Outcome o = createForFrameworkContract(req.frameworkContractId, req.extensionMonths);
            Result r = new Result();
            r.opportunities = o.created;
            r.createdCount = o.created.size();
            r.skippedMessages = o.skipped;
            r.errorMessages = o.errors;
            results.add(r);
        }
        return results;
    }

    public class Request
    {
        @InvocableVariable(label='Id du contrat cadre' required=true)
        public Id frameworkContractId;

        @InvocableVariable(label='Mois d\'extension' description='Ajouté à la date de fin actuelle de chaque contrat (vide/0 = pas d\'extension)')
        public Integer extensionMonths;
    }

    public class Result
    {
        @InvocableVariable(label='Avenants créés')
        public List<Opportunity> opportunities;

        @InvocableVariable(label='Nombre créé')
        public Integer createdCount;

        @InvocableVariable(label='Contrats ignorés')
        public List<String> skippedMessages;

        @InvocableVariable(label='Erreurs')
        public List<String> errorMessages;
    }

    // ----------------------------------------------------------------------
    // Helpers privés
    // ----------------------------------------------------------------------

    /** Vérifie que l'Id correspond bien à un contrat cadre (lève une exception sinon). */
    public static void assertIsFramework(Id frameworkContractId)
    {
        loadFramework(frameworkContractId);
    }

    private static Contract__c loadFramework(Id frameworkContractId)
    {
        List<Contract__c> frameworks = [
            SELECT Id, Name, Type__c
            FROM Contract__c
            WHERE Id = :frameworkContractId
            LIMIT 1
        ];
        if (frameworks.isEmpty())
        {
            throw new AvenantException('Contrat cadre introuvable : ' + frameworkContractId);
        }
        Contract__c framework = frameworks[0];
        if (framework.Type__c != 'Framework Agreement'
            && framework.Type__c != 'Master Service Agreement')
        {
            throw new AvenantException(
                'Le contrat ' + framework.Name + ' n\'est pas un contrat cadre ' +
                '(Type__c = "' + framework.Type__c + '").'
            );
        }
        return framework;
    }

    /**
     * Requête SOQL des contrats liés — partagée par le chemin synchrone et le
     * QueryLocator du batch. L'Id du cadre est inséré en dur (sûr : c'est un Id).
     */
    public static String childContractQuery(Id frameworkContractId)
    {
        return 'SELECT Id, Name, OwnerId, CurrencyIsoCode, '
             + 'Account__c, Account__r.Name, '
             + 'Primary_Service__c, Reference__c, '
             + 'Active_Accounting_System_Site_Count__c, Payment_Terms__c, '
             + 'Public_Private_Market__c, Tier_2_Account__c, '
             + 'Contract_Market_Segment__c, Department_FR_Contract__c, Region_FR__c, '
             + 'Effective_Annual_Revenue__c, Accounting_System_Site_Annual_Revenue__c, '
             + 'Contract_Start_Date__c, Contract_End_Date__c '
             + 'FROM Contract__c '
             + 'WHERE Parent_Contract__c = \'' + String.escapeSingleQuotes(frameworkContractId) + '\' '
             + 'ORDER BY Name';
    }

    private static List<Contract__c> loadChildContracts(Id frameworkContractId)
    {
        return (List<Contract__c>) Database.query(childContractQuery(frameworkContractId));
    }

    /** Construit l'avenant au stade OUVERT (la clôture est appliquée ensuite). */
    private static Opportunity buildAvenant(
        Contract__c child,
        Map<String, Schema.SObjectField> oppFields,
        Id recordTypeId,
        Integer extensionMonths)
    {
        Opportunity opp = new Opportunity();

        putIfWritable(opp, 'Name', buildOpportunityName(child), oppFields);
        putIfWritable(opp, 'StageName', OPP_OPEN_STAGE, oppFields);
        putIfWritable(opp, 'CloseDate', Date.today(), oppFields);
        putIfWritable(opp, 'Global_Business_Type_Opportunity__c', OPP_BUSINESS_TYPE, oppFields);
        putIfWritable(opp, 'Contract_Type__c', OPP_CONTRACT_TYPE, oppFields);
        putIfWritable(opp, 'Contract_Custom__c', child.Id, oppFields);      // lookup -> contrat lié
        putIfWritable(opp, 'CurrencyIsoCode', child.CurrencyIsoCode, oppFields);
        putIfWritable(opp, 'OwnerId', child.OwnerId, oppFields);            // -> Owner_Country__c (VR FR)
        if (recordTypeId != null)
        {
            putIfWritable(opp, 'RecordTypeId', recordTypeId, oppFields);
        }

        // Dates de contrat : reprises telles quelles, sauf la date de fin qui est
        // prolongée de extensionMonths. Le flow "Global Upsell Closed Won" recopiera
        // ensuite Opportunity.Contract_End_Date__c sur le contrat lié.
        putIfWritable(opp, 'contract_start_date__c', child.Contract_Start_Date__c, oppFields);
        putIfWritable(opp, 'Contract_End_Date__c', computeNewEndDate(child, extensionMonths), oppFields);

        for (String sourceField : FIELD_MAP.keySet())
        {
            Object value = child.get(sourceField);
            if (value != null)
            {
                putIfWritable(opp, FIELD_MAP.get(sourceField), value, oppFields);
            }
        }

        return opp;
    }

    /** Applique le statut clôturé gagné sur une opportunité déjà insérée. */
    private static void applyClosedWon(
        Opportunity opp,
        Map<String, Schema.SObjectField> oppFields)
    {
        putIfWritable(opp, 'StageName', OPP_CLOSED_STAGE, oppFields);
        putIfWritable(opp, 'Sub_Stage__c', OPP_CLOSED_SUB_STAGE, oppFields);
        putIfWritable(opp, 'CloseDate', Date.today(), oppFields);
    }

    /**
     * Nouvelle date de fin portée par l'avenant :
     *   - extensionMonths renseigné (> 0) : date de fin actuelle du contrat + N mois
     *     (null si le contrat n'a pas de date de fin) ;
     *   - sinon : date de fin actuelle du contrat (aucun changement -> contrat non modifié).
     */
    private static Date computeNewEndDate(Contract__c child, Integer extensionMonths)
    {
        Date currentEnd = child.Contract_End_Date__c;
        if (extensionMonths == null || extensionMonths <= 0)
        {
            return currentEnd;
        }
        return (currentEnd != null) ? currentEnd.addMonths(extensionMonths) : null;
    }

    /**
     * Motif d'exclusion d'un contrat, ou null s'il peut recevoir un avenant.
     * On ignore un contrat lorsque sa nouvelle date de fin serait nulle ou déjà
     * passée : le flow before-save fixant contract_start_date__c = aujourd'hui, une
     * date de fin passée déclencherait la VR "fin >= début" et le flow de clôture
     * blanchirait la date de fin du contrat.
     */
    private static String extensionSkipReason(Contract__c child, Integer extensionMonths)
    {
        Boolean extending = (extensionMonths != null && extensionMonths > 0);
        if (extending && child.Contract_End_Date__c == null)
        {
            return 'pas de date de fin sur le contrat, extension impossible';
        }
        Date newEnd = computeNewEndDate(child, extensionMonths);
        if (newEnd != null && newEnd < Date.today())
        {
            return 'contrat expiré (fin ' + child.Contract_End_Date__c +
                   (extending ? ', +' + extensionMonths + ' mois reste dans le passé' : '') + ')';
        }
        return null;
    }

    /** Nom : "<Compte> - <Service> - <Référence> - AVENANT" (aligné sur le flow). */
    private static String buildOpportunityName(Contract__c child)
    {
        List<String> parts = new List<String>();
        if (child.Account__r != null && String.isNotBlank(child.Account__r.Name))
        {
            parts.add(child.Account__r.Name);
        }
        if (String.isNotBlank(child.Primary_Service__c)) { parts.add(child.Primary_Service__c); }
        if (String.isNotBlank(child.Reference__c))       { parts.add(child.Reference__c); }
        parts.add('AVENANT');
        String name = String.join(parts, ' - ');
        return name.length() > 120 ? name.substring(0, 120) : name;
    }

    private static Id resolveRecordTypeId()
    {
        Schema.RecordTypeInfo rt = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get(OPP_RECORD_TYPE_DEVNAME);
        if (rt == null || !rt.isAvailable())
        {
            throw new AvenantException(
                'RecordType Opportunity indisponible : ' + OPP_RECORD_TYPE_DEVNAME
            );
        }
        return rt.getRecordTypeId();
    }

    /**
     * Vérifie que tous les champs universellement obligatoires (créables, non nullables,
     * sans valeur par défaut) sont renseignés. Lève une exception listant, par contrat,
     * les champs manquants — avant toute insertion.
     */
    private static void validateRequiredFields(
        List<Opportunity> opps,
        Map<Integer, Contract__c> indexToContract,
        Map<String, Schema.SObjectField> oppFields)
    {
        List<String> requiredFields = new List<String>();
        for (String apiName : oppFields.keySet())
        {
            Schema.DescribeFieldResult dfr = oppFields.get(apiName).getDescribe();
            if (dfr.isCreateable()
                && !dfr.isNillable()
                && !dfr.isDefaultedOnCreate()
                && !dfr.isAutoNumber()
                && dfr.getType() != Schema.DisplayType.BOOLEAN)
            {
                requiredFields.add(dfr.getName());
            }
        }

        List<String> problems = new List<String>();
        for (Integer i = 0; i < opps.size(); i++)
        {
            List<String> missing = new List<String>();
            for (String reqField : requiredFields)
            {
                if (opps[i].get(reqField) == null) { missing.add(reqField); }
            }
            if (!missing.isEmpty())
            {
                problems.add('Contrat ' + indexToContract.get(i).Name +
                             ' -> champs manquants : ' + String.join(missing, ', '));
            }
        }

        if (!problems.isEmpty())
        {
            throw new AvenantException(
                'Champs obligatoires non renseignés sur l\'Opportunity :\n - ' +
                String.join(problems, '\n - ') +
                '\nComplétez FIELD_MAP ou les données du/des contrat(s) lié(s).'
            );
        }
    }

    /** Écrit une valeur seulement si le champ existe et est créable dans cette org. */
    private static void putIfWritable(
        Opportunity opp,
        String fieldApiName,
        Object value,
        Map<String, Schema.SObjectField> oppFields)
    {
        if (value == null) { return; }
        Schema.SObjectField token = oppFields.get(fieldApiName.toLowerCase());
        if (token == null) { return; }
        if (!token.getDescribe().isCreateable()) { return; }
        opp.put(fieldApiName, value);
    }

    /** Concatène les messages d'erreur d'un résultat DML. */
    private static String formatErrors(List<Database.Error> errs)
    {
        List<String> msgs = new List<String>();
        for (Database.Error err : errs) { msgs.add(err.getMessage()); }
        return String.join(msgs, ' | ');
    }
}