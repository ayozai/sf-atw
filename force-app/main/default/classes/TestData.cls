@isTest
public without sharing class TestData 
{
    public static Profile p;
    public static User u;
    public static Lead partLead;
    public static Lead fullLead;
    public static Account acc;
    public static Contact cont;
    public static Event ev;
    public static Task ta;
    public static Opportunity opp;

    public static void createAll()
    {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser)
        {
            p = createProfile();
            u = createTestUser(p);
        }
        createCustomSettings();

        partLead = createLead('');
        fullLead = createLead('full');
        insert new List<Lead>{ partLead, fullLead };

        acc = createAccount();
        insert acc;
        cont = createContact(acc);
        ev = createEvent(fullLead.Id);
        opp = createOpportunity(acc);
    }

    private static Profile createProfile()
    {
        Profile pro = [select id from profile where name='System Administrator'];
        return pro;
    }

    private static User createTestUser(Profile pro)
    {
        User usr = new User(alias = 'standt', email='sevesttest@servest.co.uk', 
                emailencodingkey='UTF-8', lastname='testing', languagelocalekey='en_US', firstname='user',
                localesidkey='en_US', profileid = pro.Id, 
                timezonesidkey='America/Los_Angeles', username='sevesttest@servest.co.uk', Country = 'Barbados',
                           Division = 'Test', Recharge__c = 'Corporate');
        insert usr;

        return usr;
    }

    public static Lead createLead(String typ)
    {
        Lead l = new Lead();
        l.FirstName = 'test';
        l.LastName = 'Lead';
        l.Company = 'TestAccount';
        l.Status = 'Open';
        l.Phone = '123456789';
        l.Country = 'United Kingdom';
        // ANA : 23/12/2018 - preventing VR Exception
        l.Street = 'test street';
        l.City = 'London';
        l.PostalCode = 'SW1Y 5AY';
        // ANA : 23/12/2018 - End preventing VR Exception
        if (typ == 'full') 
        {
            l.Street = 'test street';
            if (u != null)
            {
                l.B_D_C__c = u.ID;
                l.Sales_Person__c = u.Id;
            }
            l.Contract_Review_Date__c = system.today();
            l.Contract_Start_Date__c = system.today();
            l.Division__c = 'testDiv';
            //          l.Sector_OLD__c = 'testSector';
        }
        return l;
    }

    public static Account createAccount()
    {
        Account a = new Account();
        a.Name = 'TestAccount';
        a.BillingStreet = 'Test Street';
        a.BillingCountry = 'United Kingdom';

        return a;
    }

    public static List<Account> createAccounts(Integer num)
    {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < num; i++)
        {
            Account a = createAccount();
            if (i > 0)
            {
                a.Name += i;
            }
            accounts.add(a);
        }
        return accounts;
    }

    private static Contact createContact(Account a)
    { 
        Contact c = new Contact();
        c.Account = a;
        c.Email = 'TestContact@email.com';
        c.LastName = 'TEST Contact';
        c.title = 'Job Title';
        c.OwnerID = u.Id;
        insert c;

        return c;
    }

    private static Event createEvent(Id whoId)
    {
        Event e = new Event();
        e.whoId = whoId;
        e.Subject = 'TEST EVENT';
        e.Description = 'TEST DESCRIPTION';
        e.ActivityDateTime = System.now();
        e.DurationInMinutes = 60;
        insert e;

        return e;
    }

    public static Task createTask(Id whatId)
    {
        Task t = new Task();
        t.WhatId = whatId;
        t.Subject = 'TEST EVENT';
        t.Description = 'TEST DESCRIPTION';
        t.ActivityDate = System.today();
        return t;
    }

    public static Opportunity createOpportunity(Account a)
    {
        RecordType recordType = [SELECT Id, DeveloperName FROM RecordType WHERE sObjectType = 'Opportunity' AND DeveloperName = 'Global_Bid' LIMIT 1];
        System.debug('*** Opportunity record type used in test: ' + recordType.DeveloperName + ' ***');
        
        Opportunity o  = new Opportunity();
        o.Name = 'TEST OPP';
        o.Contract_Start_Date__c = system.today().addDays(1);
        o.Contract_End_Date__c = system.today().addmonths(6);
        o.CloseDate = system.today();
        o.Amount = 1000000;
        o.AccountId = a.Id;
        o.RecordTypeId = recordType.Id;
        o.StageName = 'Analysis';
        o.Global_Primary_Service__c = 'Technical Services';
        if (u != null)
        {
            o.OwnerID = u.Id;
        }
        insert o;

        Event e = new Event();
        e.whatId = o.ID;
        e.Subject = 'TEST EVENT';
        e.Description = 'TEST DESCRIPTION';
        e.ActivityDateTime = System.now();
        e.DurationInMinutes = 60;
        insert e;

        Task oppTask = createTask(o.Id);
        insert oppTask;

        return o;
    }

    private static Contract__c createCustomerContract(Account acc)
    {
        Contract__c contract = new Contract__c();
        contract.Account__c = acc.Id;
        contract.Status__c = 'Active';
        contract.Contract_Start_Date__c = Date.Today();
        contract.Contract_End_Date__c = Date.Today().addYears(1);
        contract.Primary_Service__c = 'Technical Services';
        return contract;
    }

    public static List<Contract__c> createCustomerContracts(Integer num, List<Account> accounts)
    {
        List<Contract__c> contracts = new List<Contract__c>();
        for (Integer i = 0; i < num; i++)
        {
            Contract__c c = createCustomerContract(accounts[i]);
            if (i > 0)
            {
                //c.Name += i; TODO ?
            }
            contracts.add(c);
        }
        return contracts;
    }

    private static void createCustomSettings()
    {
        Telesales_Owner__c to = new Telesales_Owner__c(FirstName__c = 'user', LastName__c = 'testing', Name='user testing');
        insert to;
    }

    public static String getProposalsResponseMockJson()
    {
        return 
        '[ ' +
        '    {'+
        '        "proposalId": "FOLDER1-PROPOSAL1",'+
        '        "folderId": "FOLDER1",'+
        '        "name": "Mémoire technique",'+
        '        "description": null,'+
        '        "draft": false,'+
        '        "mergeFields": ['+
        '            {'+
        '                "name": "{{proposal}{scope}}",'+
        '                "type": "text",'+
        '                "value": "AO nettoyage des locaux du SDIS du 59"'+
        '            },'+
        '            {'+
        '                "name": "{{proposal}{proptitle}}",'+
        '                "type": "text",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{proposal}{validity}}",'+
        '                "type": "date",'+
        '                "value": "13-12-2021"'+
        '            },'+
        '            {'+
        '                "name": "{{company}{name}}",'+
        '                "type": "text",'+
        '                "value": "SDIS du 59"'+
        '            },'+
        '            {'+
        '                "name": "{{company}{address1}}",'+
        '                "type": "multiline",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{company}{postalcode}}",'+
        '                "type": "text",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{company}{city}}",'+
        '                "type": "text",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{company}{logo}}",'+
        '                "type": "image",'+
        '                "value": "43080944-978f-4a9d-8a6d-2457f63adf97"'+
        '            }'+
        '        ],'+
        '        "masterName": "Master Propreté - Réseaux - Offre technique",'+
        '        "owner": "DEHAENE Cyril",'+
        '        "createdAt": "2021-12-02T15:36:59.754Z",'+
        '        "updatedAt": "2021-12-13T10:15:01.100Z"'+
        '    },'+
        '    {'+
        '        "proposalId": "FOLDER1-PROPOSAL2",'+
        '        "folderId": "FOLDER1",'+
        '        "name": "Mémoire technique",'+
        '        "description": null,'+
        '        "draft": false,'+
        '        "mergeFields": ['+
        '            {'+
        '                "name": "{{proposal}{scope}}",'+
        '                "type": "text",'+
        '                "value": "AO nettoyage des locaux du SDIS du 59"'+
        '            },'+
        '            {'+
        '                "name": "{{proposal}{proptitle}}",'+
        '                "type": "text",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{proposal}{validity}}",'+
        '                "type": "date",'+
        '                "value": "13-12-2021"'+
        '            },'+
        '            {'+
        '                "name": "{{company}{name}}",'+
        '                "type": "text",'+
        '                "value": "SDIS du 59"'+
        '            },'+
        '            {'+
        '                "name": "{{company}{address1}}",'+
        '                "type": "multiline",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{company}{postalcode}}",'+
        '                "type": "text",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{company}{city}}",'+
        '                "type": "text",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{company}{logo}}",'+
        '                "type": "image",'+
        '                "value": "43080944-978f-4a9d-8a6d-2457f63adf97"'+
        '            }'+
        '        ],'+
        '        "masterName": "Master Propreté - Réseaux - Offre technique",'+
        '        "owner": "DEHAENE Cyril",'+
        '        "createdAt": "2021-12-02T15:36:59.754Z",'+
        '        "updatedAt": "2021-12-13T10:15:01.100Z"'+
        '    },'+
        '    {'+
        '        "proposalId": "FOLDER2-PROPOSAL1",'+
        '        "folderId": "FOLDER2",'+
        '        "name": "Mémoire technique - V1 - 17/01/2022 - test",'+
        '        "description": null,'+
        '        "draft": true,'+
        '        "mergeFields": ['+
        '            {'+
        '                "name": "{{proposal}{scope}}",'+
        '                "type": "text",'+
        '                "value": "Entretien des bureaux et espaces communs du siège"'+
        '            },'+
        '            {'+
        '                "name": "{{proposal}{proptitle}}",'+
        '                "type": "text",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{proposal}{validity}}",'+
        '                "type": "date",'+
        '                "value": "17-01-2022"'+
        '            },'+
        '            {'+
        '                "name": "{{company}{name}}",'+
        '                "type": "text",'+
        '                "value": "ATALIAN"'+
        '            },'+
        '            {'+
        '                "name": "{{company}{address1}}",'+
        '                "type": "multiline",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{company}{postalcode}}",'+
        '                "type": "text",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{company}{city}}",'+
        '                "type": "text",'+
        '                "value": ""'+
        '            },'+
        '            {'+
        '                "name": "{{company}{logo}}",'+
        '                "type": "image",'+
        '                "value": ""'+
        '            }'+
        '        ],'+
        '        "masterName": "Master Propreté - Marchés Publics - Offre technique",'+
        '        "owner": "HATIM Asmae",'+
        '        "createdAt": "2022-01-17T14:21:12.491Z",'+
        '        "updatedAt": "2022-01-20T14:21:56.510Z"'+
        '    }'+
        ']';
    }
}