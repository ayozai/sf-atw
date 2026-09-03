/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
trigger dlrs_Accounting_System_Site_Rea0rTrigger on Accounting_System_Site_Revenue__c
    (before delete, before insert, before update, after delete, after insert, after undelete, after update)
{
    dlrs.RollupService.triggerHandler(Accounting_System_Site_Revenue__c.SObjectType);
}