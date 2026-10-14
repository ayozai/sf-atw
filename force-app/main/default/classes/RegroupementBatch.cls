global class RegroupementBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final String STAGE_REQUALIFICATION    = 'Requalification';
    private static final String SUB_STAGE_REGROUPEMENT   = 'Réallocation périmètre'; // TODO: replace with 'Regroupement' once Sub_Stage__c picklist value is deployed
    private static final String STAGE_PROSPECT           = '2. Prospect';
    private static final String SUB_STAGE_FUTURE_OPP    = '2.1 Future Opportunity';
    private static final String RT_GLOBAL_RENEWAL        = 'Global_Renewal';
    private static final String CONTRACT_STATUS_REALLOTI = 'Réalloti';
    private static final String NOTIF_TYPE_DEV_NAME      = 'Requalification_Notif';

    @TestVisible private List<Id> selectedOppIds;
    @TestVisible private String   newOppName;
    @TestVisible private Id       targetAccountId;
    @TestVisible private Id       requestingUserId;
    @TestVisible private String   errorMessage;
    @TestVisible private Id       triggeringOppId; // for notification target

    global RegroupementBatch(List<Id> selectedOppIds, String newOppName, Id targetAccountId, Id requestingUserId) {
        this.selectedOppIds   = selectedOppIds;
        this.newOppName       = newOppName;
        this.targetAccountId  = targetAccountId;
        this.requestingUserId = requestingUserId;
        this.triggeringOppId  = (selectedOppIds != null && !selectedOppIds.isEmpty())
            ? selectedOppIds[0] : null;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, AccountId, OwnerId, Pricebook2Id, Amount,
                   Contract_Custom__c, Global_Primary_Service__c,
                   CloseDate, RecordTypeId
            FROM   Opportunity
            WHERE  Id IN :selectedOppIds
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        Savepoint sp = Database.setSavepoint();
        try {
            // 1. Close all selected opps: Requalification / Regroupement
            for (Opportunity opp : scope) {
                opp.StageName    = STAGE_REQUALIFICATION;
                opp.Sub_Stage__c = SUB_STAGE_REGROUPEMENT;
            }
            update scope;

            // 2. Aggregate data from all opps
            Set<Id> contractIds  = new Set<Id>();
            Decimal totalAmount  = 0;
            Date    closeDate    = Date.today().addYears(1);
            Id      firstOwner   = null;
            Id      firstPricebook = null;
            Id      originContractId = null; // PO-07: first opp's contract

            for (Opportunity opp : scope) {
                if (opp.Contract_Custom__c != null) contractIds.add(opp.Contract_Custom__c);
                if (opp.Amount != null) totalAmount += opp.Amount;
                if (opp.CloseDate != null && opp.CloseDate > closeDate) closeDate = opp.CloseDate;
                if (firstOwner == null) firstOwner = opp.OwnerId;
                if (firstPricebook == null) firstPricebook = opp.Pricebook2Id;
            }

            // Keep origin contract and primary service from first opp (PO-07)
            String originPrimaryService = null;
            if (!scope.isEmpty()) {
                originContractId    = scope[0].Contract_Custom__c;
                originPrimaryService = scope[0].Global_Primary_Service__c;
            }

            // 3. Mark all distinct contracts as Réalloti
            if (!contractIds.isEmpty()) {
                List<Contract__c> contracts = [SELECT Id FROM Contract__c WHERE Id IN :contractIds];
                for (Contract__c c : contracts) {
                    c.Status__c = CONTRACT_STATUS_REALLOTI;
                }
                update contracts;
            }

            // 4. Create the new grouped Global_Renewal opportunity
            Id renewalRtId = Schema.SObjectType.Opportunity
                .getRecordTypeInfosByDeveloperName()
                .get(RT_GLOBAL_RENEWAL)
                .getRecordTypeId();

            String name = (newOppName != null && newOppName.length() > 120)
                ? newOppName.substring(0, 120) : newOppName;

            Opportunity groupedOpp = new Opportunity(
                Name                       = name,
                AccountId                  = targetAccountId,
                OwnerId                    = firstOwner,
                Pricebook2Id               = firstPricebook,
                Contract_Custom__c         = originContractId,
                StageName                  = STAGE_PROSPECT,
                Sub_Stage__c               = SUB_STAGE_FUTURE_OPP,
                CloseDate                  = closeDate,
                RecordTypeId               = renewalRtId,
                Amount                     = totalAmount > 0 ? totalAmount : null,
                Global_Primary_Service__c  = originPrimaryService,
                Is_Requalification_Opp__c  = true,
                Requalification_Process__c = true
            );
            insert groupedOpp;

        } catch (Exception e) {
            Database.rollback(sp);
            errorMessage = e.getMessage();
        }
    }

    global void finish(Database.BatchableContext bc) {
        String title;
        String body;
        Integer count = selectedOppIds != null ? selectedOppIds.size() : 0;

        if (String.isBlank(errorMessage)) {
            title = 'Regroupement completed';
            body  = count + ' renewal opportunit'
                  + (count == 1 ? 'y has' : 'ies have')
                  + ' been grouped into a new renewal opportunity.';
        } else {
            title = 'Regroupement failed';
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
            notif.setTargetId(triggeringOppId);
            notif.send(new Set<String>{ requestingUserId });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Regroupement notification failed: ' + e.getMessage());
        }
    }
}
