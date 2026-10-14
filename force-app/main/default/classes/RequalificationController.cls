public with sharing class RequalificationController {

    @AuraEnabled
    public static void startRequalification(Id opportunityId, Integer numberOfNewOpps, List<String> references) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity ID is required.');
        }
        if (numberOfNewOpps == null || numberOfNewOpps < 1) {
            throw new AuraHandledException('Number of new opportunities must be at least 1.');
        }
        Id userId = UserInfo.getUserId();
        Database.executeBatch(
            new RequalificationBatch(opportunityId, numberOfNewOpps, userId, references),
            1
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchGroupableOpps(Id currentOppId, String searchTerm) {
        String pattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<Opportunity> results = [
            SELECT Id, Name, AccountId, Account.Name,
                   Contract_Custom__r.Reference__c, Amount, CloseDate
            FROM   Opportunity
            WHERE  Id != :currentOppId
              AND  RecordType.DeveloperName = 'Global_Renewal'
              AND  IsClosed = false
              AND  (Name LIKE :pattern OR Account.Name LIKE :pattern)
            LIMIT  20
        ];

        List<Map<String, Object>> output = new List<Map<String, Object>>();
        for (Opportunity opp : results) {
            output.add(new Map<String, Object>{
                'id'          => opp.Id,
                'name'        => opp.Name,
                'accountId'   => opp.AccountId,
                'accountName' => opp.Account?.Name,
                'contractRef' => opp.Contract_Custom__r?.Reference__c,
                'amount'      => opp.Amount,
                'closeDate'   => opp.CloseDate
            });
        }
        return output;
    }

    @AuraEnabled
    public static void startRegroupement(Id originOppId, List<Id> extraOppIds, String newOppName, Id targetAccountId) {
        if (originOppId == null) {
            throw new AuraHandledException('Origin opportunity ID is required.');
        }
        if (extraOppIds == null || extraOppIds.isEmpty()) {
            throw new AuraHandledException('At least one additional opportunity must be selected for grouping.');
        }
        if (String.isBlank(newOppName)) {
            throw new AuraHandledException('A name for the new grouped opportunity is required.');
        }
        if (targetAccountId == null) {
            throw new AuraHandledException('A target account is required.');
        }

        // Build full list: triggering opp first, then extras
        List<Id> allOppIds = new List<Id>{ originOppId };
        allOppIds.addAll(extraOppIds);

        // Validate all are open Global_Renewal opps
        List<Opportunity> opps = [
            SELECT Id
            FROM   Opportunity
            WHERE  Id IN :allOppIds
              AND  RecordType.DeveloperName = 'Global_Renewal'
              AND  IsClosed = false
        ];
        if (opps.size() != allOppIds.size()) {
            throw new AuraHandledException('One or more selected opportunities are not open Global Renewal opportunities.');
        }

        Id userId = UserInfo.getUserId();
        Database.executeBatch(
            new RegroupementBatch(allOppIds, newOppName, targetAccountId, userId),
            allOppIds.size()
        );
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRequalificationContext(Id opportunityId) {
        Opportunity opp = [
            SELECT Name, AccountId, Account.Name, IsClosed, Amount,
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
            'accountId'        => opp.AccountId,
            'accountName'      => opp.Account?.Name,
            'contractRef'      => opp.Contract_Custom__r?.Reference__c,
            'service'          => opp.Contract_Custom__r?.Primary_Service__c,
            'amount'           => opp.Amount,
            'isClosed'         => opp.IsClosed,
            'appContractCount' => appContractCount,
            'scenario'         => appContractCount > 0 ? 2 : 1
        };
    }
}
