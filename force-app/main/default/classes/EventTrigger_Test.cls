@isTest
private class EventTrigger_Test {

    @TestSetup
    static void setup() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User restrictedUser = buildUser('event.restricted@test.iacrm202.com', stdProfile.Id, true);
        User bypassUser     = buildUser('event.bypass@test.iacrm202.com',     stdProfile.Id, true);
        insert new List<User>{ restrictedUser, bypassUser };

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'PS_EventDeleteBypass' LIMIT 1];
        insert new PermissionSetAssignment(
            AssigneeId      = bypassUser.Id,
            PermissionSetId = ps.Id
        );
    }

    // Utilisateur sans bypass — suppression bloquée
    @isTest
    static void testDelete_blocked() {
        User restrictedUser = getUser('event.restricted@test.iacrm202.com');

        Event evt = createEvent(restrictedUser.Id);
        System.runAs(restrictedUser) { insert evt; }

        Test.startTest();
        System.runAs(restrictedUser) {
            try {
                delete evt;
                System.assert(false, 'Une exception aurait dû être levée');
            } catch (DmlException e) {
                System.assert(
                    e.getMessage().contains('not authorized'),
                    'Le message doit mentionner l\'absence d\'autorisation'
                );
            }
        }
        Test.stopTest();
    }

    // Utilisateur avec bypass — suppression autorisée
    @isTest
    static void testDelete_bypass() {
        User bypassUser = getUser('event.bypass@test.iacrm202.com');

        Event evt = createEvent(bypassUser.Id);
        System.runAs(bypassUser) { insert evt; }

        Test.startTest();
        System.runAs(bypassUser) {
            try {
                delete evt;
            } catch (DmlException e) {
                System.assert(false, 'La suppression ne devrait pas être bloquée : ' + e.getMessage());
            }
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Event WHERE Id = :evt.Id], 'L\'événement doit avoir été supprimé');
    }

    // Bulk — 200 events bloqués
    @isTest
    static void testDelete_bulk_blocked() {
        User restrictedUser = getUser('event.restricted@test.iacrm202.com');

        List<Event> events = new List<Event>();
        for (Integer i = 0; i < 200; i++) {
            events.add(createEvent(restrictedUser.Id));
        }
        System.runAs(restrictedUser) { insert events; }

        Test.startTest();
        System.runAs(restrictedUser) {
            try {
                delete events;
                System.assert(false, 'Une exception aurait dû être levée');
            } catch (DmlException e) {
                System.assert(e.getMessage().contains('not authorized'), 'Erreur attendue sur suppression bulk');
            }
        }
        Test.stopTest();

        System.assertEquals(200, [SELECT COUNT() FROM Event WHERE Id IN :events], '200 événements doivent être encore présents');
    }

    // ─── Helpers ────────────────────────────────────────────────────────────────

    private static User getUser(String username) {
        return [SELECT Id FROM User WHERE Username = :username LIMIT 1];
    }

    private static Event createEvent(Id ownerId) {
        return new Event(
            Subject              = 'Test Event',
            OwnerId              = ownerId,
            ActivityDateTime     = System.now().addDays(1),
            DurationInMinutes    = 60
        );
    }

    private static User buildUser(String username, Id profileId, Boolean isActive) {
        String alias = username.left(8).replace('@', '_');
        return new User(
            Username          = username,
            Email             = username,
            LastName          = 'TestUser',
            Alias             = alias.left(8),
            TimeZoneSidKey    = 'Europe/Paris',
            LocaleSidKey      = 'fr_FR',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'fr',
            Country           = 'France',
            Division          = 'France',
            Recharge__c       = 'Country',
            ProfileId         = profileId,
            IsActive          = isActive
        );
    }
}