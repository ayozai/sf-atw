@isTest
private class OpptyTriggerContactroleCount_Test{
  /**
      *       
      * @category  : Test Class
      * @author    : ANA
      * @purpose   : Test class of Opportunity Trigger
      * @Date      : 23/09/2018
 */     
 @isTest 
 static void test_OpportunityTrigger(){ 
    System.Test.startTest();   
   
   
        // 1. Create Account        
        
        String strAccountRecordTypeId = [Select Id From RecordType Where SobjectType = 'Account' and DeveloperName = 'Global_Account'].Id;
        Account acct = new Account(Name='TEST ACCOUNT', RecordTypeId=strAccountRecordTypeId, Atalian_Sector__c='Corporate');
            System.debug('Account Name : ' + acct.Name);
        try{
            insert acct;
            }
        catch(Exception e){

        string errormessage1 = e.getMessage();
        System.debug('Account Error inserting : ' + errormessage1);  
        }
              
        // 2. Create Contact
        String strContactdRecordTypeId = [Select Id From RecordType Where SobjectType = 'Contact' and DeveloperName = 'Global_Contact'].Id;
        Contact cnt =  new Contact(LastName='TEST', FirstName='TESTCONTACT', RecordTypeId=strContactdRecordTypeId);
            System.debug('Contact Name : ' + cnt.LastName); 
      
        try{
            insert cnt;
            }
        catch(Exception e){

        string errormessage2 = e.getMessage();
        System.debug('Account Error inserting : ' + errormessage2);  
        }
               
        // 3. Create Opportunity  
        String strOpptydRecordTypeId = [Select Id From RecordType Where SobjectType = 'Opportunity' AND DeveloperName = 'Global_Bid' LIMIT 1].Id;
        Opportunity opp = new Opportunity(Name=acct.Name + 'Test Opportunity',
        StageName='Qualification',
        Opportunity_Description__c = 'TEST',
        Contract_Type__c = 'Contractual',                                  
        Sub_Services__c = 'Chartered Surveying',                                  
        Environment__c = 'Bar',
        GPpercent__c = 20,
        Sub_Stage__c = 'A. Future Opportunity', 
        Site_Names__c = 'TEST SITES',
        Process_Start_Date__c = System.today(),
        contract_start_date__c = System.today().addMonths(2),
        Contract_End_Date__c =System.today().addMonths(3),                                          
        AccountId = acct.Id, CloseDate=System.today().addMonths(1), RecordTypeId=strOpptydRecordTypeId);                                         
                                          
        System.debug('Opportunity Name : ' + opp.Name);  
      
        try{
            insert opp;
        }
        catch(Exception e){

        string errormessage3 = e.getMessage();
        System.debug('Opportunity Error inserting : ' + errormessage3);  
        }
        
        
        // 4. Create Oppty Contact role
        OpportunityContactRole opportunitycontactrole_Obj = new OpportunityContactRole(OpportunityId = opp.id, ContactId = cnt.id, IsPrimary = true, Role = 'Decision Maker');
        
        try{
            Insert opportunitycontactrole_Obj;
        }
        catch(Exception e){

        string errormessage4 = e.getMessage();
        System.debug('opportunitycontactrole_Obj Error inserting : ' + errormessage4);  
        }              
           
        System.assertEquals('TEST', opp.Opportunity_Description__c );
        try {
            opp = [SELECT Number_of_Contacts_Roles_Assigned__c, Primary_Contact_Assigned__c  FROM Opportunity WHERE Id =:opp.Id LIMIT 1];
            System.debug('Number_of_Contacts_Roles_Assigned after trigger fired xxxxxxxxxxxx: ' + opp.Number_of_Contacts_Roles_Assigned__c);
        } catch (QueryException e) {
            System.debug('No records found for the specified Opportunity Id.');
        }
        
        // Final Update of Oppty
        // Test that the trigger correctly updated the Number_of_Contacts_Roles_Assigned__c
        
        try{
           Opportunity opp2 = [Select Id, Number_of_Contacts_Roles_Assigned__c from Opportunity where Id =:opp.Id];
           opp2.NextStep = 'Final Update of Oppty';
           update opp2;
        }
        catch (QueryException e){
           System.debug('No records found for the specified Opportunity Id.');
        } 
        catch(Exception e){
           string errormessage5 = e.getMessage();
           System.debug('Opportunity Error updating : ' + errormessage5);  
        }
        
        // Retrieve the Count of Contact Role from Opportunity
        try{
           Opportunity opp3 = [Select Id, Number_of_Contacts_Roles_Assigned__c from Opportunity where Id =:opp.Id];
           System.debug('Number_of_Contacts_Roles_Assigned after trigger 3  fired xxxxxxxxxxxx: ' + opp3.Number_of_Contacts_Roles_Assigned__c);      
           System.assertEquals(1, opp3.Number_of_Contacts_Roles_Assigned__c);   
        }catch (QueryException e){
           System.debug('No records found for the specified Opportunity Id.');
        }
       
      System.Test.stopTest();
      } 
}