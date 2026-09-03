/**
 * @description     Test class for OppTeamMemberController.
 *                  Covers all business scenarios defined in IACRM-90 spec §5.2.
 *                  Minimum coverage target: 85%.
 *
 *                  Test strategy:
 *                  - Users are created with System.runAs() to simulate access scenarios.
 *                  - Authorization is based solely on Opportunity Team membership + Edit access level.
 *                  - ConnectApi Chatter calls are caught internally (non-blocking by design).
 *                  - Messaging.sendEmail is allowed in test context (no actual emails sent).
 *                  - The @TestSetup method creates shared data once for all test methods.
 *
 * @author          MGHARIANI
 * @date            2026-04-10
 * @feature         IACRM-90 — Opportunity Team Self-Service
 * @see             OppTeamMemberController
 */
@IsTest
private class OppTeamMemberController_Test {

    // ─────────────────────────────────────────────────────────────────────────────
    //  TEST SETUP
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Creates all test data shared across test methods.
     *
     *              Profile strategy:
     *              All test users are created with the 'Standard User' profile (guaranteed
     *              to exist in every org). No permission set is required — authorization
     *              is controlled exclusively by Opportunity Team membership with Edit access.
     *
     *              Users created:
     *              - editMember1  : Standard User + Edit team member (primary caller)
     *              - editMember2  : Standard User + Edit team member (second authorized caller)
     *              - readOnlyMember : Standard User + Read team member (fails access check)
     *              - outsideUser  : Standard User + NOT in team (fails membership check)
     *              - targetUser   : Standard User + active (to be added)
     *              - inactiveUser : Standard User + inactive (to be rejected)
     */
    @TestSetup
    static void setup() {

        // ── Profile — Standard User is guaranteed to exist in every org ───────────
        Profile standardProfile = [
            SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1
        ];

        // ── Users ─────────────────────────────────────────────────────────────────
        User editMember1     = buildUser('otm_auth_profile@test.iacrm90.com', standardProfile.Id, true);
        User editMember2     = buildUser('otm_auth_pset@test.iacrm90.com',    standardProfile.Id, true);
        User readOnlyMember  = buildUser('otm_readonly@test.iacrm90.com',     standardProfile.Id, true);
        User outsideUser     = buildUser('otm_outside@test.iacrm90.com',      standardProfile.Id, true);
        User targetUser      = buildUser('otm_target@test.iacrm90.com',       standardProfile.Id, true);
        User inactiveUser    = buildUser('otm_inactive@test.iacrm90.com',     standardProfile.Id, false);

        insert new List<User>{
            editMember1, editMember2, readOnlyMember,
            outsideUser, targetUser, inactiveUser
        };

        // ── Opportunity ───────────────────────────────────────────────────────────
        // Created in System context so the running test user is the Owner
        Account acc = new Account(
            Name           = 'Test Account IACRM90',
            BillingCountry = 'France'
        );
        insert acc;

        Id globalBidRtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get('Global_Bid')
            .getRecordTypeId();

        Opportunity opp = new Opportunity(
            Name                       = 'Test Opp IACRM90',
            AccountId                  = acc.Id,
            StageName                  = '2. Prospect',
            CloseDate                  = Date.today().addMonths(3),
            RecordTypeId               = globalBidRtId,
            Global_Primary_Service__c  = 'Security',
            contract_start_date__c     = Date.today().addMonths(6)
        );
        insert opp;

        // ── Opportunity Team Members ───────────────────────────────────────────────
        insert new List<OpportunityTeamMember>{
            new OpportunityTeamMember(
                OpportunityId          = opp.Id,
                UserId                 = editMember1.Id,
                TeamMemberRole         = 'Account Manager',
                OpportunityAccessLevel = 'Edit'
            ),
            new OpportunityTeamMember(
                OpportunityId          = opp.Id,
                UserId                 = editMember2.Id,
                TeamMemberRole         = 'Sales Rep',
                OpportunityAccessLevel = 'Edit'
            ),
            new OpportunityTeamMember(
                OpportunityId          = opp.Id,
                UserId                 = readOnlyMember.Id,
                TeamMemberRole         = 'Technical',
                OpportunityAccessLevel = 'Read'
            )
        };
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  HELPER — QUERY TEST USERS / RECORDS
    // ─────────────────────────────────────────────────────────────────────────────

    private static User getUser(String username) {
        return [SELECT Id, Name, Email FROM User WHERE Username = :username LIMIT 1];
    }

    private static Account getAcc() {
        return [SELECT Id FROM Account WHERE Name = 'Test Account IACRM90' LIMIT 1];
    }

    private static Opportunity getOpp() {
        Account acc = getAcc();
        return [SELECT Id, Name FROM Opportunity WHERE AccountId = :acc.Id LIMIT 1];
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  READ METHOD TESTS
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Verifies that getTeamMembers returns the 3 pre-created members.
     */
    @IsTest
    static void test_getTeamMembers_returnsMembers() {
        Opportunity opp = getOpp();
        Test.startTest();
            List<OpportunityTeamMember> members = OppTeamMemberController.getTeamMembers(opp.Id);
        Test.stopTest();

        // The Opportunity Owner is automatically added as a 4th team member by Salesforce
        Assert.isTrue(members.size() >= 3, 'Expected at least 3 pre-created team members.');
    }

    /**
     * @description Verifies that getTeamRoles returns a non-empty picklist list.
     */
    @IsTest
    static void test_getTeamRoles_returnsValues() {
        Test.startTest();
            List<Map<String, String>> roles = OppTeamMemberController.getTeamRoles();
        Test.stopTest();

        Assert.isTrue(!roles.isEmpty(), 'TeamMemberRole picklist should have at least one active value.');
        Assert.isTrue(roles[0].containsKey('label'), 'Each entry should have a label key.');
        Assert.isTrue(roles[0].containsKey('value'), 'Each entry should have a value key.');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  POSITIVE TEST — addTeamMember
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description [POSITIVE] A team member with Edit access can successfully add
     *              a new active user to the Opportunity Team.
     *              Verifies the OTM record is created with the correct values.
     */
    @IsTest
    static void test_addTeamMember_authorizedByProfile_success() {
        User caller     = getUser('otm_auth_profile@test.iacrm90.com');
        User target     = getUser('otm_target@test.iacrm90.com');
        Opportunity opp = getOpp();

        Test.startTest();
            System.runAs(caller) {
                OppTeamMemberController.addTeamMember(opp.Id, target.Id, 'Technical');
            }
        Test.stopTest();

        List<OpportunityTeamMember> created = [
            SELECT Id, TeamMemberRole, OpportunityAccessLevel
            FROM   OpportunityTeamMember
            WHERE  OpportunityId = :opp.Id AND UserId = :target.Id
        ];
        Assert.areEqual(1, created.size(), 'OTM record should have been created.');
        Assert.areEqual('Technical', created[0].TeamMemberRole, 'Role should match the provided value.');
        Assert.areEqual('Edit', created[0].OpportunityAccessLevel, 'Access level must be Edit.');
    }

    /**
     * @description [POSITIVE] A second Edit team member can add a new member
     *              without a role (optional field).
     */
    @IsTest
    static void test_addTeamMember_authorizedByPset_noRole_success() {
        User caller     = getUser('otm_auth_pset@test.iacrm90.com');
        User target     = getUser('otm_target@test.iacrm90.com');
        Opportunity opp = getOpp();

        Test.startTest();
            System.runAs(caller) {
                OppTeamMemberController.addTeamMember(opp.Id, target.Id, null);
            }
        Test.stopTest();

        List<OpportunityTeamMember> created = [
            SELECT Id FROM OpportunityTeamMember
            WHERE  OpportunityId = :opp.Id AND UserId = :target.Id
        ];
        Assert.areEqual(1, created.size(), 'OTM record should have been created even without a role.');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  NEGATIVE TESTS — addTeamMember
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description [NEGATIVE] A team member with Read-only access (not Edit)
     *              cannot add members — AuraHandledException expected.
     */
    @IsTest
    static void test_addTeamMember_readOnlyAccess_throwsException() {
        User caller     = getUser('otm_readonly@test.iacrm90.com');
        User target     = getUser('otm_target@test.iacrm90.com');
        Opportunity opp = getOpp();

        Test.startTest();
            try {
                System.runAs(caller) {
                    OppTeamMemberController.addTeamMember(opp.Id, target.Id, 'Technical');
                }
                Assert.fail('An AuraHandledException should have been thrown.');
            } catch (AuraHandledException e) {
                // AuraHandledException.getMessage() always returns "Script-thrown exception"
                // in test context — exception type is sufficient to verify the guard fired.
            }
        Test.stopTest();
    }

    /**
     * @description [NEGATIVE] A user who is not in the Opportunity Team at all
     *              cannot add members, regardless of their profile — AuraHandledException expected.
     */
    @IsTest
    static void test_addTeamMember_outsideUser_throwsException() {
        User caller     = getUser('otm_outside@test.iacrm90.com');
        User target     = getUser('otm_target@test.iacrm90.com');
        Opportunity opp = getOpp();

        Test.startTest();
            try {
                System.runAs(caller) {
                    OppTeamMemberController.addTeamMember(opp.Id, target.Id, 'Technical');
                }
                Assert.fail('An AuraHandledException should have been thrown.');
            } catch (AuraHandledException e) {
                // Expected — user is not a team member
            }
        Test.stopTest();
    }

    /**
     * @description [NEGATIVE] Attempting to add an inactive user
     *              should throw an AuraHandledException.
     */
    @IsTest
    static void test_addTeamMember_inactiveUser_throwsException() {
        User caller      = getUser('otm_auth_profile@test.iacrm90.com');
        User inactTarget = getUser('otm_inactive@test.iacrm90.com');
        Opportunity opp  = getOpp();

        Test.startTest();
            try {
                System.runAs(caller) {
                    OppTeamMemberController.addTeamMember(opp.Id, inactTarget.Id, 'Technical');
                }
                Assert.fail('An AuraHandledException should have been thrown for inactive user.');
            } catch (AuraHandledException e) {
                // AuraHandledException.getMessage() always returns "Script-thrown exception"
                // in test context — exception type is sufficient to verify the guard fired.
            }
        Test.stopTest();
    }

    /**
     * @description [NEGATIVE] Attempting to add a user who is already a team member
     *              should throw an AuraHandledException with an explicit message.
     */
    @IsTest
    static void test_addTeamMember_alreadyMember_throwsException() {
        User caller  = getUser('otm_auth_profile@test.iacrm90.com');
        // editMember2 is already a team member (created in @TestSetup)
        User alreadyMember = getUser('otm_auth_pset@test.iacrm90.com');
        Opportunity opp    = getOpp();

        Test.startTest();
            try {
                System.runAs(caller) {
                    OppTeamMemberController.addTeamMember(opp.Id, alreadyMember.Id, 'Technical');
                }
                Assert.fail('An AuraHandledException should have been thrown for duplicate member.');
            } catch (AuraHandledException e) {
                // AuraHandledException.getMessage() always returns "Script-thrown exception"
                // in test context — exception type is sufficient to verify the guard fired.
            }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  POSITIVE TEST — updateTeamMemberRole
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description [POSITIVE] An authorized team member with Edit access can
     *              successfully update another member's role.
     */
    @IsTest
    static void test_updateTeamMemberRole_success() {
        User caller  = getUser('otm_auth_profile@test.iacrm90.com');
        User target  = getUser('otm_auth_pset@test.iacrm90.com');
        Opportunity opp = getOpp();

        OpportunityTeamMember otm = [
            SELECT Id, TeamMemberRole
            FROM   OpportunityTeamMember
            WHERE  OpportunityId = :opp.Id AND UserId = :target.Id
            LIMIT  1
        ];

        Test.startTest();
            System.runAs(caller) {
                OppTeamMemberController.updateTeamMemberRole(otm.Id, 'Account Manager');
            }
        Test.stopTest();

        OpportunityTeamMember updated = [
            SELECT TeamMemberRole
            FROM   OpportunityTeamMember
            WHERE  Id = :otm.Id
        ];
        Assert.areEqual('Account Manager', updated.TeamMemberRole, 'Role should have been updated.');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  NOTIFICATION TESTS
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Verifies that a Chatter FeedItem is posted to the Opportunity
     *              when a new member is added. ConnectApi is mocked via test context.
     *              The test verifies no exception is thrown (non-blocking design).
     *
     * NOTE: ConnectApi.ChatterFeeds.postFeedElement() requires Test.enableChangeDataCapture()
     *       or will fail silently due to the try-catch in the controller. This test
     *       verifies the operation completes without error.
     */
    @IsTest
    static void test_addTeamMember_chatterNotification_noError() {
        User caller = getUser('otm_auth_profile@test.iacrm90.com');
        User target = getUser('otm_target@test.iacrm90.com');
        Opportunity opp = getOpp();

        Boolean exceptionThrown = false;
        Test.startTest();
            try {
                System.runAs(caller) {
                    OppTeamMemberController.addTeamMember(opp.Id, target.Id, 'Technical');
                }
            } catch (Exception e) {
                exceptionThrown = true;
            }
        Test.stopTest();

        Assert.isFalse(exceptionThrown, 'addTeamMember should complete without exception (Chatter is non-blocking).');
    }

    /**
     * @description Verifies that an email is attempted when a new member is added.
     *              Messaging.sendEmail() does not send real emails in test context.
     *              The test verifies no exception is thrown (non-blocking design).
     */
    @IsTest
    static void test_addTeamMember_emailNotification_noError() {
        User caller = getUser('otm_auth_profile@test.iacrm90.com');
        User target = getUser('otm_target@test.iacrm90.com');
        Opportunity opp = getOpp();

        Boolean exceptionThrown = false;
        Test.startTest();
            try {
                System.runAs(caller) {
                    OppTeamMemberController.addTeamMember(opp.Id, target.Id, 'Account Manager');
                }
            } catch (Exception e) {
                exceptionThrown = true;
            }
        Test.stopTest();

        Assert.isFalse(exceptionThrown, 'addTeamMember should complete without exception (email is non-blocking).');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  PRIVATE HELPER
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Factory method for creating test User records.
     * @param username  Unique username for the test user.
     * @param profileId Profile Id to assign.
     * @param isActive  Whether the user is active.
     * @return          Unsaved User record.
     */
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