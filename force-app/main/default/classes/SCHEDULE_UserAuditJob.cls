/**
 * SCHEDULE_UserAuditJob
 * 
 * Scheduled job to run the user audit batch(es). Expected to be run every day immediately AFTER midnight
 * 
 * Author : Bernard Price (Brightgen)
 * Created: 2022-10-18
 * 
 * Changes:
 */
public without sharing class SCHEDULE_UserAuditJob implements Schedulable
{
    public void execute(SchedulableContext SC)
    {
        BATCH_UserAuditDailyUpdates batchProcess = new BATCH_UserAuditDailyUpdates();
        Database.executeBatch(batchProcess, 50);
    }
}