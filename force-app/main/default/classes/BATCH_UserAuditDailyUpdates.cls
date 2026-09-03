/**
 * BATCH_UserAuditDailyUpdates
 * 
 * Batch job to run the user audit updates. Expected to be run every day immediately AFTER midnight
 * 
 * Author : Bernard Price (Brightgen)
 * Created: 2022-10-18
 * 
 * Changes:
 */
public without sharing class BATCH_UserAuditDailyUpdates implements Database.Batchable<User>
{
    @TestVisible
    private Date processDate = System.Today().addDays(-1);

    public List<User> start(Database.BatchableContext BC)
    {
        return UserAuditUtils.getUsersForDailyLicenceAudit(processDate);
    }

    public void execute(Database.BatchableContext BC, List<User> scope)
    {
        UserAuditUtils.processUsersForDailyLicenceAudit(processDate, scope);
    }

    public void finish(Database.BatchableContext BC)
    {
        // Only run the tidy-up batch if we're at the end of a period and not in unit test context (can't chain batches)
        if (UserAuditUtils.isProcessDateEndOfPeriodForBreakdowns(processDate) && !Test.isRunningTest())
        {
            BATCH_UserAuditPeriodicClosure periodEndJob = new BATCH_UserAuditPeriodicClosure(processDate);
            Database.executeBatch(periodEndJob, 50);
        }
    }
}