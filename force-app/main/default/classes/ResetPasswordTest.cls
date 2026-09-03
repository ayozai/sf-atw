@isTest
private class ResetPasswordTest {
    @isTest
    static void testResetUserPassword() {
        // Create test data
        List<User> users = new List<User>();
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User']; // Assuming a profile with the name 'Standard User' exists
        
        for (Integer i = 0; i < 5; i++) {
            User u = new User(
                FirstName = 'Test',
                LastName = 'User ' + i,
                Email = 'testuser' + i + '@example.com',
                Username = 'testuser' + i + '@resetpasswordtest.com',
                IsActive = true,
                Alias = 'T' + i,
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = profile.Id,
                LanguageLocaleKey = 'en_US',
                Country = 'United States',
                Division = 'Test',
                Recharge__c = 'Country'
            );
            users.add(u);
        }
        insert users;
        
        List<List<String>> userIds = new List<List<String>>();
        List<String> idList = new List<String>();
        for (User u : users) {
            idList.add(u.Id);
        }
        userIds.add(idList);
        
        // Call the method under test
        Test.startTest();
        ResetPassword.ResetUserPassword(userIds);
        Test.stopTest();
        
        // Verify the results
        List<User> updatedUsers = [SELECT Id, LastPasswordChangeDate FROM User WHERE Id IN :users];
        Date today = Date.today();
        for (User u : updatedUsers) {
            System.assertNotEquals(null, u.LastPasswordChangeDate, 'LastPasswordChangeDate should not be null');
        }
    }
}