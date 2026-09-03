@isTest
private class TestOlbicoCdp {

    @isTest
    static void validateOlbicoCdpController () {
        
        Account testAccount = new Account( Name = 'TEST COMPANY', BillingStreet = 'Street 1', BillingPostalCode = 'AAAA00', BillingCity = 'AMSTERDAM', BillingCountry = 'Netherlands',DUNS__c = '123456789' );
        Insert testAccount;
        
        PageReference pageRef = Page.OlbicoCdpNewAccount; 
        pageref.getParameters().put('accid',testAccount.Id);
        pageref.getParameters().put('recordType','012D00000003KX3');
        
       
        Test.setCurrentPage(pageRef);
       
        ApexPages.StandardController stdController = new ApexPages.StandardController(testAccount);
        OlbicoCdpController olbicoCdpController = new OlbicoCdpController(stdController);
        
        System.assertNotEquals(olbicoCdpController.getLanguage(), null);
        System.assertNotEquals(olbicoCdpController.getToken(), null);
        System.assertNotEquals(olbicoCdpController.getParams(), '*');
        System.assertEquals(olbicoCdpController.getCompanyName(), EncodingUtil.urlEncode(testAccount.Name, 'UTF-8'));
        System.assertEquals(olbicoCdpController.getCompanyAddress(), testAccount.BillingStreet);
        System.assertEquals(olbicoCdpController.getCompanyPostcode(), testAccount.BillingPostalCode);
        System.assertEquals(olbicoCdpController.getCompanyCity(), testAccount.BillingCity);
        System.assertEquals(olbicoCdpController.getCompanyCountry(), testAccount.BillingCountry);
        System.assertEquals(olbicoCdpController.getCompanyDuns(), testAccount.DUNS__c);   
        System.assertEquals(olbicoCdpController.getCompanyRegistrationNumber(), null);
        System.assertEquals(olbicoCdpController.getRecordType(),'012D00000003KX3');
        
        
    }
    
    @isTest
    static void validateNewAccountRedirectController() {
        Account testAccount = new Account();
        ApexPages.StandardController stdController = new ApexPages.StandardController(testAccount);
        /*
            NewAccountRedirectController testController = new NewAccountRedirectController(stdController);
            System.assertNotEquals(testController.Redirect(), null);
        */
    }
}