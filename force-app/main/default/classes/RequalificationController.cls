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
}
