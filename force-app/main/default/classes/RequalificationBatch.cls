global class RequalificationBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final String STAGE_REQUALIFICATION       = 'Requalification';
    private static final String SUB_STAGE_CLOSED_LOST       = '6.1 Closed Lost';
    private static final String STAGE_PROSPECT              = '2. Prospect';
    private static final String SUB_STAGE_FUTURE_OPP        = '2.1 Future Opportunity';
    private static final String RT_GLOBAL_RENEWAL           = 'Global_Renewal';
    private static final String CONTRACT_STATUS_REALLOTI    = 'Réalloti';
    private static final String CONTRACT_STATUS_ACTIVE      = 'Active';
    private static final String CONTRACT_TYPE_FRAMEWORK     = 'Framework Agreement';
    private static final String NOTIF_TYPE_DEV_NAME         = 'Requalification_Notif';
    private static final String CREATE_FUTURE_OPP_YES       = 'Yes';

    @TestVisible private Id           originOppId;
    @TestVisible private Integer      numberOfNewOpps;
    @TestVisible private Id           requestingUserId;
    @TestVisible private String       errorMessage;
    @TestVisible private List<String> references;

    global RequalificationBatch(Id originOppId, Integer numberOfNewOpps, Id requestingUserId, List<String> references) {
        this.originOppId      = originOppId;
        this.numberOfNewOpps  = numberOfNewOpps;
        this.requestingUserId = requestingUserId;
        this.references       = references;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, AccountId, OwnerId,
                   Contract_Custom__c,
                   Contract_Custom__r.Reference__c,
                   Contract_Custom__r.Primary_Service__c,
                   Contract_Custom__r.Account__r.Name,
                   Contract_Custom__r.Type__c,
                   Contract_Custom__r.Contract_Market_Segment__c,
                   Contract_Custom__r.Region_FR__c,
                   Contract_Custom__r.Department_FR_Contract__c,
                   Contract_Custom__r.OwnerId,
                   Contract_Custom__r.Tier_2_Account__c,
                   Contract_Custom__r.Public_Private_Market__c,
                   CloseDate, RecordTypeId, Global_Primary_Service__c
            FROM   Opportunity
            WHERE  Id = :originOppId
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        try {
            Opportunity origin     = scope[0];
            Id          contractId = origin.Contract_Custom__c;

            // 1. Close the origin opportunity in the "Requalification" stage.
            //    The VR_FR_DontCreateNewRebidOpport check (Number_of_Open_Renewal_Opps__c > 0)
            //    is satisfied by closing the origin first, which drops the roll-up to 0.
            origin.StageName    = STAGE_REQUALIFICATION;
            origin.Sub_Stage__c = SUB_STAGE_CLOSED_LOST;
            update origin;

            // 2. Detect scenario and handle contract logic
            //    Scenario 1: no app contracts → mark framework contract Réalloti, create new one
            //    Scenario 2: app contracts exist → mark them Réalloti, close their renewal opps
            Id newContractId = contractId; // default for Scenario 2

            if (contractId != null) {
                List<Contract__c> appContracts = [
                    SELECT Id, Status__c
                    FROM   Contract__c
                    WHERE  Parent_Contract__c = :contractId
                ];

                if (appContracts.isEmpty()) {
                    newContractId = handleScenario1(origin, contractId);
                } else {
                    handleScenario2(contractId, appContracts);
                    // Scenario 2: new opps link to the existing framework contract
                }
            }

            // 3. Create N new Global_Renewal renewal opportunities
            Id renewalRtId = Schema.SObjectType.Opportunity
                .getRecordTypeInfosByDeveloperName()
                .get(RT_GLOBAL_RENEWAL)
                .getRecordTypeId();

            Date closeDate = origin.CloseDate != null
                ? origin.CloseDate
                : Date.today().addYears(1);

            List<Opportunity> newOpps = new List<Opportunity>();
            for (Integer i = 1; i <= numberOfNewOpps; i++) {
                String siteRef = (references != null && i <= references.size())
                    ? references.get(i - 1) : null;
                newOpps.add(new Opportunity(
                    Name                          = buildOppName(origin, i, siteRef),
                    AccountId                     = origin.AccountId,
                    OwnerId                       = origin.OwnerId,
                    Contract_Custom__c            = newContractId,
                    StageName                     = STAGE_PROSPECT,
                    Sub_Stage__c                  = SUB_STAGE_FUTURE_OPP,
                    CloseDate                     = closeDate,
                    RecordTypeId                  = renewalRtId,
                    Global_Primary_Service__c     = origin.Global_Primary_Service__c,
                    Create_future_opportunity__c  = CREATE_FUTURE_OPP_YES,
                    Is_Requalification_Opp__c     = true,
                    Site_Names__c                 = siteRef
                ));
            }
            insert newOpps;

        } catch (Exception e) {
            errorMessage = e.getMessage();
        }
    }

    /**
     * Scenario 1: Framework contract has no application contracts.
     * Marks the old framework contract as Réalloti. New renewal opportunities are linked
     * to this same Réalloti contract. When an opp is won, the Requalification_Closed_Won
     * flow creates a Single-Site Contract and relinks the opp.
     * Returns the Id of the (now Réalloti) framework contract.
     */
    private static Id handleScenario1(Opportunity origin, Id contractId) {
        update new Contract__c(Id = contractId, Status__c = CONTRACT_STATUS_REALLOTI);
        return contractId;
    }

    /**
     * Scenario 2: Framework contract has application contracts.
     * Marks all application contracts as Réalloti and closes any open
     * Global_Renewal opportunities linked to them (stage = Requalification).
     */
    private static void handleScenario2(Id contractId, List<Contract__c> appContracts) {
        // Mark app contracts as Réalloti
        Set<Id> appContractIds = new Set<Id>();
        for (Contract__c c : appContracts) {
            c.Status__c = CONTRACT_STATUS_REALLOTI;
            appContractIds.add(c.Id);
        }
        update appContracts;

        // Close open Global_Renewal opportunities linked to those app contracts
        List<Opportunity> oldRenewalOpps = [
            SELECT Id
            FROM   Opportunity
            WHERE  Contract_Custom__c IN :appContractIds
              AND  RecordType.DeveloperName = :RT_GLOBAL_RENEWAL
              AND  IsClosed = false
        ];
        if (!oldRenewalOpps.isEmpty()) {
            for (Opportunity o : oldRenewalOpps) {
                o.StageName    = STAGE_REQUALIFICATION;
                o.Sub_Stage__c = SUB_STAGE_CLOSED_LOST;
            }
            update oldRenewalOpps;
        }
    }

    /**
     * Builds the opportunity name following the same convention as AvenantOpportunityCreator:
     * "<Account Name> - <Primary Service> - <Reference> - REQUALIFICATION N"
     * Truncated to 120 characters.
     */
    @TestVisible
    private static String buildOppName(Opportunity origin, Integer index, String siteRef) {
        List<String> parts = new List<String>();

        String accountName = origin.Contract_Custom__r?.Account__r?.Name;
        String service     = origin.Contract_Custom__r?.Primary_Service__c;
        String reference   = origin.Contract_Custom__r?.Reference__c;

        if (String.isNotBlank(accountName)) parts.add(accountName);
        if (String.isNotBlank(service))     parts.add(service);
        if (String.isNotBlank(reference))   parts.add(reference);
        if (String.isNotBlank(siteRef))     parts.add(siteRef);
        parts.add('REQUALIFICATION ' + index);

        String name = String.join(parts, ' - ');
        return name.length() > 120 ? name.substring(0, 120) : name;
    }

    global void finish(Database.BatchableContext bc) {
        String title;
        String body;

        if (String.isBlank(errorMessage)) {
            title = 'Requalification completed';
            body  = numberOfNewOpps + ' renewal opportunit'
                  + (numberOfNewOpps == 1 ? 'y has' : 'ies have')
                  + ' been successfully created.';
        } else {
            title = 'Requalification failed';
            body  = 'An error occurred: ' + errorMessage;
        }

        try {
            CustomNotificationType notifType = [
                SELECT Id
                FROM   CustomNotificationType
                WHERE  DeveloperName = :NOTIF_TYPE_DEV_NAME
                LIMIT  1
            ];
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setTitle(title);
            notif.setBody(body);
            notif.setNotificationTypeId(notifType.Id);
            notif.setTargetId(originOppId);
            notif.send(new Set<String>{ requestingUserId });
        } catch (Exception e) {
            // Notification failure should not surface as an error to the user
            System.debug(LoggingLevel.WARN, 'Requalification notification failed: ' + e.getMessage());
        }
    }
}
