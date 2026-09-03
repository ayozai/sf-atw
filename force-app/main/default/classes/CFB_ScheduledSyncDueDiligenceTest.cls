@isTest
public class CFB_ScheduledSyncDueDiligenceTest {

    @isTest
    static void testExecuteRunsBatch() {
        Test.startTest();
        new CFB_ScheduledSyncDueDiligence().execute(null);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT ApexClass.Name, Status
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'CFB_BatchSyncDueDiligence'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Completed', job.Status);
    }

    @isTest
    static void testSchedule() {
        Test.startTest();
        String jobId = System.schedule(
            'CFB Rattrapage quotidien Test', '0 0 22 * * ?', new CFB_ScheduledSyncDueDiligence());
        Test.stopTest();

        CronTrigger ct = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals('0 0 22 * * ?', ct.CronExpression);
    }
}