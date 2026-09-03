/**
 * UserAuditUtils_Test
 * 
 * Unit test class for UserAuditUtils
 * 
 * Author : Bernard Price (Brightgen)
 * Created: 2022-10-18
 * 
 * Changes:
 */
@isTest
public without sharing class UserAuditUtils_Test 
{
    private final static Date TEST_PROCESS_DATE = Date.newInstance(System.Today().year(), 12, 21);
    private final static Date TEST_PROCESS_DATE_EOY = Date.newInstance(System.Today().year(), 12, 31);

    private static void setupCostTable()
    {
        List<Dated_User_Licence_Cost__mdt> costs = new List<Dated_User_Licence_Cost__mdt>();
        costs.add(new Dated_User_Licence_Cost__mdt(Licence_Type__c = 'Salesforce', Cost_Period__c = 'Annual', Cost__c = 150.00, User_Profile_Licence__c = true, Activity_Based_On_Login__c = false));
        costs.add(new Dated_User_Licence_Cost__mdt(Licence_Type__c = 'Customer Community Plus', Cost_Period__c = 'Monthly', Cost__c = 15.00, User_Profile_Licence__c = true, Activity_Based_On_Login__c = true));
        costs.add(new Dated_User_Licence_Cost__mdt(Licence_Type__c = 'Customer Community Plus Login', Cost_Period__c = 'Daily', Cost__c = 7.50, User_Profile_Licence__c = true, Activity_Based_On_Login__c = true));
        costs.add(new Dated_User_Licence_Cost__mdt(Licence_Type__c = 'CRM User', Cost_Period__c = 'Annual', Cost__c = 80.00, User_Profile_Licence__c = false, Activity_Based_On_Login__c = false));
        costs.add(new Dated_User_Licence_Cost__mdt(Licence_Type__c = 'Service Cloud User', Cost_Period__c = 'Annual', Cost__c = 55.00, User_Profile_Licence__c = false, Activity_Based_On_Login__c = false, 
            Feature_Licence__c = true, Feature_Licence_User_Field_API_Name__c = 'USERPERMISSIONSSUPPORTUSER'));
        UserAuditUtils.populateCacheForUnitTest(costs);
    }

    private static User createUser(String name, String profileLicenceType, String permissionSetLicenceType)
    {
        return createUser(name, profileLicenceType, permissionSetLicenceType, null);
    }

    private static User createUser(String name, String profileLicenceType, String permissionSetLicenceType, String featureLicenceField)
    {
        String nameBase = UserAuditUtils.UNIT_TEST_USERNAME_BASE;
        User u = new User(
            IsActive = true, 
            Alias = name.left(4),
            Email = 'test'+name+'@UserAuditUtilsTest.com',
            EmailEncodingKey = 'ISO-8859-1',
            FirstName = name,
            LanguageLocaleKey = 'en_US',
            LastName = name,
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id,UserLicense.Name FROM Profile WHERE UserLicense.Name = :profileLicenceType LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = nameBase+name+'@UserAuditUtilsTest.com',
            Country = 'United Kingdom',
            Division = 'Global',
            Recharge__c = 'Country'
        );
        if (!String.isEmpty(featureLicenceField))
        {
            u.put(featureLicenceField, true);
        }
        insert u;
        if (!String.isEmpty(permissionSetLicenceType))
        {
            List<PermissionSetLicense> permSetLicences = [SELECT Id FROM PermissionSetLicense WHERE MasterLabel = :permissionSetLicenceType];
            if (permSetLicences.size() > 0)
            {
                PermissionSetLicenseAssign licenceAssign = new PermissionSetLicenseAssign(PermissionSetLicenseId = permSetLicences[0].Id, AssigneeId = u.Id);
                insert licenceAssign;
            }
        }
        return u;
    }

    private static User createExternalUser(String name, String profileLicenceType)
    {
        String nameBase = UserAuditUtils.UNIT_TEST_USERNAME_BASE;
        String email = 'test'+name+'@UserAuditUtilsTest.com';
        Account externalAccount = new Account(Name = 'Test Customer');
        insert externalAccount;
        Contact con = new Contact(AccountId = externalAccount.Id, LastName = name, Email = email);
        insert con;
        User u = new User(
            IsActive = true, 
            ContactId = con.Id,
            Alias = name.left(4),
            Email = email,
            EmailEncodingKey = 'ISO-8859-1',
            FirstName = name,
            LanguageLocaleKey = 'en_US',
            LastName = name,
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id,UserLicense.Name FROM Profile WHERE UserLicense.Name = :profileLicenceType ORDER BY CreatedDate DESC LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = nameBase+name+'@UserAuditUtilsTest.com',
            Country = 'United Kingdom',
            Division = 'Global',
            Recharge__c = 'Country'
        );
        insert u;
        return u;
    }

    private static User_Licence_Audit__c createHistoricalAudit(User u, String licenceType, Boolean profile, Boolean loginBased, Date startDate, Date endDate, String period, Decimal cost)
    {
        User_Licence_Audit__c audit = new User_Licence_Audit__c(
            User__c = u.Id,
            Licence_Type__c = licenceType,
            User_Profile_Licence__c = profile,
            Activity_Based_On_Login__c = loginBased, 
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Cost_Period__c = period,
            Cost__c = cost,
            CurrencyISOCode = UserAuditUtils.CORPORATE_CURRENCY
        );
        return audit;
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditNoRecords() 
    {
        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no new audits');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditNoTrackedLicenceTypes() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Chatter Free', null);
        }

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no new audits');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditNewActiveUserTrackedProfileLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', null);
        }

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(1, audits.size(), 'There should be 1 new audit');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE, audits[0].Start_Date__c, 'Audit should start today');
        System.assertEquals(null, audits[0].End_Date__c, 'Audit should be open-ended');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditNewActiveUserTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should be 2 new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE, audits[0].Start_Date__c, 'Audit should start today');
        System.assertEquals(null, audits[0].End_Date__c, 'Audit should be open-ended');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE, audits[1].Start_Date__c, 'Audit should start today');
        System.assertEquals(null, audits[1].End_Date__c, 'Audit should be open-ended');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditStillActiveUserTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 150.00);
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should be no new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[0].End_Date__c, 'Audit should be open-ended');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[1].End_Date__c, 'Audit should be open-ended');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditDeactivateUserTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 150.00);
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1.IsActive = false;
            update user1;
        }

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should be no new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE, audits[0].End_Date__c, 'Audit should now be closed');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE, audits[1].End_Date__c, 'Audit should now be closed');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditRemoveTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 150.00);
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            delete [SELECT Id FROM PermissionSetLicenseAssign WHERE AssigneeId = :user1.Id];
        }

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should be no new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[0].End_Date__c, 'Audit should still be open');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE, audits[1].End_Date__c, 'Audit should now be closed');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditReactivateUserNextDayTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-14), TEST_PROCESS_DATE.addDays(-1), 'Annual', 150.00);
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-14), TEST_PROCESS_DATE.addDays(-1), 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should be no new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-14), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[0].End_Date__c, 'Audit should be reopened');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-14), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[1].End_Date__c, 'Audit should be reopened');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditReactivateUserDaysLaterTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-14), TEST_PROCESS_DATE.addDays(-7), 'Annual', 150.00);
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-14), TEST_PROCESS_DATE.addDays(-7), 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(4, audits.size(), 'There should be 2 new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-14), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-7), audits[0].End_Date__c, 'Audit should be reopened');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-14), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-7), audits[1].End_Date__c, 'Audit should have ended before today');
        System.assertEquals(user1.Id, audits[2].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[2].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[2].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[2].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE, audits[2].Start_Date__c, 'Audit should start today');
        System.assertEquals(null, audits[2].End_Date__c, 'Audit should be open-ended');
        System.assertEquals(user1.Id, audits[3].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[3].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[3].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[3].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE, audits[3].Start_Date__c, 'Audit should starte today');
        System.assertEquals(null, audits[3].End_Date__c, 'Audit should be open-ended');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditReactivateUserNextDayStartOfNewPeriodTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE_EOY.addDays(-14), TEST_PROCESS_DATE_EOY, 'Annual', 150.00);
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE_EOY.addDays(-14), TEST_PROCESS_DATE_EOY, 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE_EOY.addDays(1);
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(4, audits.size(), 'There should be 2 new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE_EOY.addDays(-14), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE_EOY, audits[0].End_Date__c, 'Audit should have closed before today');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE_EOY.addDays(-14), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE_EOY, audits[1].End_Date__c, 'Audit should have closed before today');
        System.assertEquals(user1.Id, audits[2].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[2].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[2].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[2].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE_EOY.addDays(1), audits[2].Start_Date__c, 'Audit should start today');
        System.assertEquals(null, audits[2].End_Date__c, 'Audit should be open-ended');
        System.assertEquals(user1.Id, audits[3].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[3].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[3].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[3].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE_EOY.addDays(1), audits[3].Start_Date__c, 'Audit should start today');
        System.assertEquals(null, audits[3].End_Date__c, 'Audit should be open-ended');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditChangeUserProfileSameLicenceTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 150.00);
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1.ProfileId = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Salesforce' AND Id <> :user1.ProfileId LIMIT 1].Id;
            update user1;
        }

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should be no new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[0].End_Date__c, 'Audit should still be open');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[1].End_Date__c, 'Audit should still be open');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditDailyLoginBasedLicenceFirstLogin()
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createExternalUser('1user', 'Customer Community Plus Login');
        }

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no audits');

        UserAuditUtils.forceCommunitiesLoginDates.add(TEST_PROCESS_DATE);

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Cost_Period__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(1, audits.size(), 'There should be 1 new audit');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Customer Community Plus Login', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(7.50, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals('Daily', audits[0].Cost_Period__c, 'Audit should be based on a month period');
        System.assertEquals(TEST_PROCESS_DATE, audits[0].Start_Date__c, 'Audit should start and end today');
        System.assertEquals(TEST_PROCESS_DATE, audits[0].End_Date__c, 'Audit should start and end today');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditMonthlyLoginBasedLicenceFirstLogin()
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createExternalUser('1user', 'Customer Community Plus');
        }

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no audits');

        UserAuditUtils.forceCommunitiesLoginDates.add(TEST_PROCESS_DATE);

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Cost_Period__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(1, audits.size(), 'There should be 1 new audit');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Customer Community Plus', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(15.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals('Monthly', audits[0].Cost_Period__c, 'Audit should be based on a month period');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth(), audits[0].Start_Date__c, 'Audit should start at the start of this month');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth().addMonths(1).addDays(-1), audits[0].End_Date__c, 'Audit should end at the end of this month');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditMonthlyLoginBasedLicenceSecondLoginNextMonth()
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createExternalUser('1user', 'Customer Community Plus');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Customer Community Plus', true, true, TEST_PROCESS_DATE.toStartOfMonth().addMonths(-1), TEST_PROCESS_DATE.toStartOfMonth().addDays(-1), 'Monthly', 15.00);
        insert new List<User_Licence_Audit__c>{ audit1 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(1, audits.size(), 'There should be no audits');

        UserAuditUtils.forceCommunitiesLoginDates.add(TEST_PROCESS_DATE);

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Cost_Period__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(1, audits.size(), 'There should be no new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Customer Community Plus', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(15.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals('Monthly', audits[0].Cost_Period__c, 'Audit should be based on a month period');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth().addMonths(-1), audits[0].Start_Date__c, 'Audit should start at the start of last month');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth().addMonths(1).addDays(-1), audits[0].End_Date__c, 'Audit should end at the end of this month');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditMonthlyLoginBasedLicenceSecondLoginMonthsLater()
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createExternalUser('1user', 'Customer Community Plus');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Customer Community Plus', true, true, TEST_PROCESS_DATE.toStartOfMonth().addMonths(-2), TEST_PROCESS_DATE.toStartOfMonth().addMonths(-1).addDays(-1), 'Monthly', 15.00);
        insert new List<User_Licence_Audit__c>{ audit1 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(1, audits.size(), 'There should be no audits');

        UserAuditUtils.forceCommunitiesLoginDates.add(TEST_PROCESS_DATE);

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Cost_Period__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should be no new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Customer Community Plus', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(15.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals('Monthly', audits[0].Cost_Period__c, 'Audit should be based on a month period');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth().addMonths(-2), audits[0].Start_Date__c, 'Audit should start at the start of month before last');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth().addMonths(-1).addDays(-1), audits[0].End_Date__c, 'Audit should end at the end of month before last');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('Customer Community Plus', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(15.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals('Monthly', audits[1].Cost_Period__c, 'Audit should be based on a month period');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth(), audits[1].Start_Date__c, 'Audit should start at the start of this month');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth().addMonths(1).addDays(-1), audits[1].End_Date__c, 'Audit should end at the end of this month');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditStillActiveUserChangeCostTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 125.00); // Simulate this being cheaper before, now 150 in the MDT
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(3, audits.size(), 'There should be 1 new audit');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(125.00, audits[0].Cost__c, 'Audit should have its original cost');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[0].End_Date__c, 'Audit should have been closed');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[1].End_Date__c, 'Audit should be open-ended');
        System.assertEquals(user1.Id, audits[2].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[2].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[2].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[2].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE, audits[2].Start_Date__c, 'Audit should start today');
        System.assertEquals(null, audits[2].End_Date__c, 'Audit should be open-ended');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditReactivateUserNextDayChangeCostTrackedPermSetLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-14), TEST_PROCESS_DATE.addDays(-1), 'Annual', 125.00); // Simulate this being cheaper before, now 150 in the MDT
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-14), TEST_PROCESS_DATE.addDays(-1), 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(3, audits.size(), 'There should be 1 new audit');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(125.00, audits[0].Cost__c, 'Audit should have its original cost');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-14), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[0].End_Date__c, 'Audit should have ended before today');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('CRM User', audits[1].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(80.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-14), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[1].End_Date__c, 'Audit should be reopened');
        System.assertEquals(user1.Id, audits[2].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[2].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[2].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[2].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE, audits[2].Start_Date__c, 'Audit should have start today');
        System.assertEquals(null, audits[2].End_Date__c, 'Audit should be open-ended');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditMonthlyLoginBasedLicenceChangeCostSecondLoginSameMonth()
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createExternalUser('1user', 'Customer Community Plus');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Customer Community Plus', true, true, TEST_PROCESS_DATE.toStartOfMonth(), TEST_PROCESS_DATE.addMonths(1).toStartOfMonth().addDays(-1), 'Monthly', 10.00); // Simulate this being cheaper before, now 15 in the MDT
        insert new List<User_Licence_Audit__c>{ audit1 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(1, audits.size(), 'There should be no audits');

        UserAuditUtils.forceCommunitiesLoginDates.add(TEST_PROCESS_DATE);

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Cost_Period__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(1, audits.size(), 'There should be no new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Customer Community Plus', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(10.00, audits[0].Cost__c, 'Audit should have its original cost');
        System.assertEquals('Monthly', audits[0].Cost_Period__c, 'Audit should be based on a month period');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth(), audits[0].Start_Date__c, 'Audit should start at the start of this month');
        System.assertEquals(TEST_PROCESS_DATE.toStartOfMonth().addMonths(1).addDays(-1), audits[0].End_Date__c, 'Audit should end at the end of this month');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditNewActiveUserTrackedFeatureLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', null, 'USERPERMISSIONSSUPPORTUSER');
        }

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no audits');

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should be 2 new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE, audits[0].Start_Date__c, 'Audit should start today');
        System.assertEquals(null, audits[0].End_Date__c, 'Audit should be open-ended');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('Service Cloud User', audits[1].Licence_Type__c, 'Audit should be created for the feature licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the feature licence type');
        System.assertEquals(55.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE, audits[1].Start_Date__c, 'Audit should start today');
        System.assertEquals(null, audits[1].End_Date__c, 'Audit should be open-ended');
    }

    @isTest
    private static void testProcessUsersForDailyLicenceAuditRemoveTrackedFeatureLicence() 
    {
        setupCostTable();
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', null, 'USERPERMISSIONSSUPPORTUSER');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 150.00);
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'Service Cloud User', false, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 55.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2 };

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should already be 2 audits');

        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1.USERPERMISSIONSSUPPORTUSER = false;
            update user1;
        }

        Test.startTest();

        BATCH_UserAuditDailyUpdates dailyUpdates = new BATCH_UserAuditDailyUpdates();
        dailyUpdates.processDate = TEST_PROCESS_DATE;
        Database.executeBatch(dailyUpdates, 50);

        Test.stopTest();

        audits = [SELECT Id,User__c,Licence_Type__c,Cost__c,Start_Date__c,End_Date__c,User_Profile_Licence__c FROM User_Licence_Audit__c];
        System.assertEquals(2, audits.size(), 'There should be no new audits');
        System.assertEquals(user1.Id, audits[0].User__c, 'Audit should be created against correct user');
        System.assertEquals('Salesforce', audits[0].Licence_Type__c, 'Audit should be created for the profile licence type');
        System.assertEquals(true, audits[0].User_Profile_Licence__c, 'Audit should be created for the profile licence type');
        System.assertEquals(150.00, audits[0].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[0].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(null, audits[0].End_Date__c, 'Audit should still be open');
        System.assertEquals(user1.Id, audits[1].User__c, 'Audit should be created against correct user');
        System.assertEquals('Service Cloud User', audits[1].Licence_Type__c, 'Audit should be created for the feature licence type');
        System.assertEquals(false, audits[1].User_Profile_Licence__c, 'Audit should be created for the feature licence type');
        System.assertEquals(55.00, audits[1].Cost__c, 'Audit should have the cost from the metadata table');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-1), audits[1].Start_Date__c, 'Audit should have started before today');
        System.assertEquals(TEST_PROCESS_DATE, audits[1].End_Date__c, 'Audit should now be closed');
    }

    @isTest
    private static void testCloseUserLicenceAuditsNoRecords() 
    {
        Test.startTest();

        BATCH_UserAuditPeriodicClosure closureBatch = new BATCH_UserAuditPeriodicClosure(TEST_PROCESS_DATE);
        Database.executeBatch(closureBatch, 50);

        Test.stopTest();

        List<User_Licence_Audit__c> audits = [SELECT Id FROM User_Licence_Audit__c];
        System.assertEquals(0, audits.size(), 'There should be no audits');
    }

    @isTest
    private static void testCloseUserLicenceAudits() 
    {
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', 'CRM User');
        }

        User_Licence_Audit__c audit1 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-14), TEST_PROCESS_DATE.addDays(-7), 'Annual', 150.00);
        User_Licence_Audit__c audit2 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-14), TEST_PROCESS_DATE.addDays(-7), 'Annual', 80.00);
        User_Licence_Audit__c audit3 = createHistoricalAudit(user1, 'Salesforce', true, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 150.00);
        User_Licence_Audit__c audit4 = createHistoricalAudit(user1, 'CRM User', false, false, TEST_PROCESS_DATE.addDays(-1), null, 'Annual', 80.00);
        insert new List<User_Licence_Audit__c>{ audit1, audit2, audit3, audit4 };

        Test.startTest();

        BATCH_UserAuditPeriodicClosure closureBatch = new BATCH_UserAuditPeriodicClosure(TEST_PROCESS_DATE);
        Database.executeBatch(closureBatch, 50);

        Test.stopTest();

        List<User_Licence_Audit__c> audits = [SELECT Id,End_Date__c FROM User_Licence_Audit__c];
        System.assertEquals(4, audits.size(), 'There should still be 4 audits');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-7), audits[0].End_Date__c, 'Audit should have ended before today');
        System.assertEquals(TEST_PROCESS_DATE.addDays(-7), audits[1].End_Date__c, 'Audit should have ended before today');
        System.assertEquals(TEST_PROCESS_DATE, audits[2].End_Date__c, 'Audit should now be closed');
        System.assertEquals(TEST_PROCESS_DATE, audits[3].End_Date__c, 'Audit should now be closed');
    }

    @isTest
    private static void testGetLoginHistoriesByUserId()
    {
        Test.startTest();

        Map<Id, List<LoginHistory>> logins = UserAuditUtils.getLoginHistoriesByUserId(System.Today(), new Set<Id>{ UserInfo.getUserId() });

        Test.stopTest();

        system.assertNotEquals(0, logins.size(), 'At least 1 login for the current user should have been found');
    }

    @isTest
    private static void testScheduledJobForCoverage() 
    {
        User user1;
        System.runAs(new User(Id = UserInfo.getUserId()))
        {
            user1 = createUser('1user', 'Salesforce', null);
        }

        Test.startTest();

        SCHEDULE_UserAuditJob sch = new SCHEDULE_UserAuditJob();
        sch.execute(null);

        Test.stopTest();
    }
}