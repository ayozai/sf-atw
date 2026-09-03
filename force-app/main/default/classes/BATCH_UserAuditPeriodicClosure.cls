/**
 * BATCH_UserAuditPeriodicClosure
 * 
 * Batch job to run the user audit breakdown closures. Expected to be run automatically following the daily
 * job based on whether we have reached the boundary between e.g. quarters
 * 
 * Author : Bernard Price (Brightgen)
 * Created: 2022-10-18
 * 
 * Changes:
 */
public without sharing class BATCH_UserAuditPeriodicClosure  implements Database.Batchable<User_Licence_Audit__c>
{
    @TestVisible
    private Date processDate;

    public BATCH_UserAuditPeriodicClosure(Date processDate)
    {
        this.processDate = processDate;
    }

    public List<User_Licence_Audit__c> start(Database.BatchableContext BC)
    {
        return UserAuditUtils.getUserLicenceAuditsForPeriodicClosure(processDate);
    }

    public void execute(Database.BatchableContext BC, List<User_Licence_Audit__c> scope)
    {
        UserAuditUtils.closeUserLicenceAudits(processDate, scope);
        
    }

    public void finish(Database.BatchableContext BC)
    {
        
    }
}