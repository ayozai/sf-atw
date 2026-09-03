/**
 * @description Scheduler pour lancer le batch automatiquement
 * CRON Expression : tous les 15 du mois à 01h00
 */
public class InspectionScheduler implements Schedulable {
    
    /**
     * @description Exécution programmée
     */
    public void execute(SchedulableContext sc) {
        // Lancer le batch avec la date du jour
        InspectionBatch batch = new InspectionBatch();
        Database.executeBatch(batch, 200);
    }
    
    /**
     * @description Méthode utilitaire pour planifier le job
     * Tous les 15 du mois à 01h00
     */
    public static String scheduleMonthly() {
        String cronExp = '0 0 1 15 * ?'; // Le 15 de chaque mois à 01h00
        String jobName = 'InspectionMonthlyScheduler_' + String.valueOf(System.now().getTime());
        
        return System.schedule(jobName, cronExp, new InspectionScheduler());
    }
}