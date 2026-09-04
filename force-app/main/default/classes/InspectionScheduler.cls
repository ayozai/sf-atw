/**
 * @description Scheduler pour lancer le batch automatiquement
 * CRON Expression : le 1er de chaque mois à 01h00
 */
public class InspectionScheduler implements Schedulable {

    /**
     * @description Exécution programmée
     */
    public void execute(SchedulableContext sc) {
        InspectionBatch batch = new InspectionBatch();
        Database.executeBatch(batch, 200);
    }

    /**
     * @description Méthode utilitaire pour planifier le job
     * Le 1er de chaque mois à 01h00 (FIX : était le 15)
     */
    public static String scheduleMonthly() {
        String cronExp = '0 0 1 1 * ?';
        String jobName = 'InspectionMonthlyScheduler_' + String.valueOf(System.now().getTime());
        return System.schedule(jobName, cronExp, new InspectionScheduler());
    }
}