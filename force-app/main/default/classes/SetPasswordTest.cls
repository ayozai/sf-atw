@isTest
private class SetPasswordTest {
    @isTest
    static void testSetUserPassword() {
        // Create test data
        List<User> users = new List<User>();
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User']; // Assuming a profile with the name 'Standard User' exists
        
        for (Integer i = 0; i < 5; i++) {
            User u = new User(
                FirstName = 'Test',
                LastName = 'User ' + i,
                Email = 'testuser' + i + '@example.com',
                Username = 'testuser' + i + '@setpasswordtest.com',
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
        
        List<SetPassword.PasswordInput> passwordInputs = new List<SetPassword.PasswordInput>();
        for (User u : users) {
            SetPassword.PasswordInput input = new SetPassword.PasswordInput();
            input.userIds = new List<Id>{ u.Id };
            input.password = 'NewPassword123!';
            passwordInputs.add(input);
        }
        
        // Call the method under test
        Test.startTest();
        SetPassword.SetUserPassword(passwordInputs);
        Test.stopTest();
        
        // Verify the results
        List<User> updatedUsers = [SELECT Id, LastPasswordChangeDate FROM User WHERE Id IN :users];
        Date today = Date.today();
        for (User u : updatedUsers) {
            System.assertEquals(today, u.LastPasswordChangeDate.date(), 'LastPasswordChangeDate should be today');
        }
    }
}