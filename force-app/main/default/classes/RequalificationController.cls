public with sharing class RequalificationController {

    @AuraEnabled
    public static void startRequalification(Id opportunityId, Integer numberOfNewOpps) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required.');
        }
        if (numberOfNewOpps == null || numberOfNewOpps < 1) {
            throw new AuraHandledException('Number of new opportunities must be at least 1.');
        }
        Id userId = UserInfo.getUserId();
        Database.executeBatch(
            new RequalificationBatch(opportunityId, numberOfNewOpps, userId),
            1
        );
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRequalificationContext(Id opportunityId) {
        Opportunity opp = [
            SELECT Name, Account.Name, IsClosed,
                   Contract_Custom__c,
                   Contract_Custom__r.Reference__c,
                   Contract_Custom__r.Primary_Service__c
            FROM   Opportunity
            WHERE  Id = :opportunityId
        ];

        Integer appContractCount = 0;
        if (opp.Contract_Custom__c != null) {
            appContractCount = [
                SELECT COUNT() FROM Contract__c
                WHERE  Parent_Contract__c = :opp.Contract_Custom__c
            ];
        }

        return new Map<String, Object>{
            'oppName'          => opp.Name,
            'accountName'      => opp.Account?.Name,
            'contractRef'      => opp.Contract_Custom__r?.Reference__c,
            'service'          => opp.Contract_Custom__r?.Primary_Service__c,
            'isClosed'         => opp.IsClosed,
            'appContractCount' => appContractCount,
            'scenario'         => appContractCount > 0 ? 2 : 1
        };
    }
}
