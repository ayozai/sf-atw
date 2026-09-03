public without sharing class TriggerHelperAccount 
{
    @testVisible
    private static Boolean DUNSAccountHierarchyUpdated = false;
    
    public static void HandleBeforeInsert(List<Account> newAccs) 
    {
        if (!DUNSAccountHierarchyUpdated)
        {
            //updateDUNSAccountHierarchy(newAccs, null);
            DUNSAccountHierarchyUpdated = true;
        }
    }

    public static void HandleBeforeUpdate(List<Account> newAccs, Map<Id, Account> oldAccs) 
    {
        if (!DUNSAccountHierarchyUpdated)
        {
            //updateDUNSAccountHierarchy(newAccs, oldAccs);
            DUNSAccountHierarchyUpdated = true;
        }
    }
    
    public static void HandleAfterInsert(List<Account> newAccs) 
    {
        
    }

    public static void HandleAfterUpdate(List<Account> newAccs, Map<Id, Account> oldAccs) 
    {
        
    }

    public static void HandleAfterDelete(Map<Id, Account> oldAccs) 
    {
        
    }

    public static void HandleAfterUndelete(List<Account> newAccs) 
    {
        
    }
    
    public static void updateDUNSAccountHierarchy(List<Account> newAccs, Map<Id, Account> oldAccs)
    {

    }
}