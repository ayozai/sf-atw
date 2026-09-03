/**
 * @description Classe de test pour InspectionScheduler
 */
@isTest
private class InspectionSchedulerTest {

    /**
     * @description Test de l'exécution de la méthode execute() du scheduler
     */
    @isTest
    static void testSchedulerExecute() {
        Test.startTest();
            // Planifier le job avec l'expression CRON du 15 de chaque mois à 01h00
            String cronExp = '0 0 1 15 * ?';
            String jobName = 'TestInspectionScheduler_Execute';
            
            InspectionScheduler scheduler = new InspectionScheduler();
            String jobId = System.schedule(jobName, cronExp, scheduler);
        Test.stopTest();
        
        // Vérifier que le job a bien été créé
        CronTrigger ct = [
            SELECT Id, CronExpression, State, CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        System.assertEquals(cronExp, ct.CronExpression, 'L\'expression CRON doit correspondre au 15 de chaque mois à 01h00');
        System.assertEquals('WAITING', ct.State, 'Le job doit être en attente');
        System.assertEquals(jobName, ct.CronJobDetail.Name, 'Le nom du job doit correspondre');
    }
    
    /**
     * @description Test de la méthode utilitaire scheduleMonthly()
     */
    @isTest
    static void testScheduleMonthly() {
        Test.startTest();
            String jobId = InspectionScheduler.scheduleMonthly();
        Test.stopTest();
        
        // Vérifier que le job a bien été créé et enregistré
        System.assertNotEquals(null, jobId, 'Le jobId ne doit pas être null');
        
        CronTrigger ct = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        System.assertEquals('0 0 1 15 * ?', ct.CronExpression, 'L\'expression CRON doit correspondre au 15 de chaque mois à 01h00');
        System.assertEquals('WAITING', ct.State, 'Le job doit être en attente après planification');
    }
    
    /**
     * @description Test que deux appels à scheduleMonthly() génèrent des noms de jobs uniques
     */
    @isTest
    static void testJobNameUniqueness() {
        Test.startTest();
            String jobId1 = InspectionScheduler.scheduleMonthly();
            String jobId2 = InspectionScheduler.scheduleMonthly();
        Test.stopTest();
        
        System.assertNotEquals(jobId1, jobId2, 'Chaque appel doit générer un job avec un identifiant unique');
    }
}