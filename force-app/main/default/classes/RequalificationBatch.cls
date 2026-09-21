global class RequalificationBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final String STAGE_REQUALIFICATION       = 'Requalification';
    private static final String SUB_STAGE_CLOSED_LOST       = '6.1 Closed Lost';
    private static final String STAGE_PROSPECT              = '2. Prospect';
    private static final String SUB_STAGE_FUTURE_OPP        = '2.1 Future Opportunity';
    private static final String RT_GLOBAL_RENEWAL           = 'Global_Renewal';
    private static final String CONTRACT_STATUS_REALLOCATED = 'Reallocated';
    private static final String NOTIF_TYPE_DEV_NAME         = 'Requalification_Notif';

    @TestVisible private Id      originOppId;
    @TestVisible private Integer numberOfNewOpps;
    @TestVisible private Id      requestingUserId;
    @TestVisible private String  errorMessage;

    global RequalificationBatch(Id originOppId, Integer numberOfNewOpps, Id requestingUserId) {
        this.originOppId      = originOppId;
        this.numberOfNewOpps  = numberOfNewOpps;
        this.requestingUserId = requestingUserId;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, AccountId, Contract_Custom__c,
                   CloseDate, RecordTypeId, Global_Primary_Service__c
            FROM   Opportunity
            WHERE  Id = :originOppId
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        try {
            Opportunity origin    = scope[0];
            Id          contractId = origin.Contract_Custom__c;

            // 1. Close origin opportunity first so the roll-up drops to 0
            //    before inserting new opps (prevents VR from firing)
            origin.StageName    = STAGE_REQUALIFICATION;
            origin.Sub_Stage__c = SUB_STAGE_CLOSED_LOST;
            update origin;

            // 2. Close application contracts if the framework contract has any
            if (contractId != null) {
                List<Contract__c> appContracts = [
                    SELECT Id
                    FROM   Contract__c
                    WHERE  Parent_Contract__c = :contractId
                ];
                if (!appContracts.isEmpty()) {
                    for (Contract__c c : appContracts) {
                        c.Status__c = CONTRACT_STATUS_REALLOCATED;
                    }
                    update appContracts;
                }
            }

            // 3. Create N new Global_Renewal opportunities linked to the same framework contract
            Id renewalRtId = Schema.SObjectType.Opportunity
                .getRecordTypeInfosByDeveloperName()
                .get(RT_GLOBAL_RENEWAL)
                .getRecordTypeId();

            Date closeDate = origin.CloseDate != null
                ? origin.CloseDate
                : Date.today().addYears(1);

            List<Opportunity> newOpps = new List<Opportunity>();
            for (Integer i = 0; i < numberOfNewOpps; i++) {
                newOpps.add(new Opportunity(
                    Name                      = origin.Name + ' - Renewal ' + (i + 1),
                    AccountId                 = origin.AccountId,
                    Contract_Custom__c        = contractId,
                    StageName                 = STAGE_PROSPECT,
                    Sub_Stage__c              = SUB_STAGE_FUTURE_OPP,
                    CloseDate                 = closeDate,
                    RecordTypeId              = renewalRtId,
                    Global_Primary_Service__c = origin.Global_Primary_Service__c
                ));
            }
            insert newOpps;

        } catch (Exception e) {
            errorMessage = e.getMessage();
        }
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
