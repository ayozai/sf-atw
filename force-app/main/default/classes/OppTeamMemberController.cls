/**
 * @description     Apex controller for the Opportunity Team Self-Service feature.
 *                  Exposes @AuraEnabled methods to the addOpportunityTeamMember LWC,
 *                  allowing qualified team members to add users to or update roles in
 *                  an Opportunity Team without Owner intervention.
 *
 *                  Security model:
 *                  - Outer class runs with sharing (SOQL respects user visibility).
 *                  - The only access condition: caller must be an OpportunityTeamMember
 *                    with OpportunityAccessLevel = Edit on the target Opportunity.
 *                  - No profile or permission set restriction (managed via visibility
 *                    filters at a later stage — v2 scope).
 *                  - DML is delegated to the inner class OppTeamMemberDML (without sharing)
 *                    to bypass the OWD Private restriction, following the principle of
 *                    least privilege.
 *
 * @author          MGHARIANI
 * @date            2026-04-10
 * @feature         IACRM-90 — Opportunity Team Self-Service
 * @testClass       OppTeamMemberController_Test
 * @see             addOpportunityTeamMember (LWC)
 */
public with sharing class OppTeamMemberController {

    // ─── Constants ───────────────────────────────────────────────────────────────
    private static final String ACCESS_LEVEL_EDIT  = 'Edit';

    // ─── Chatter Message Templates ────────────────────────────────────────────────
    // {0} = caller name, {1} = target user name, {2} = role
    private static final String CHATTER_TPL_ADD  = '{0} added {1} to the Opportunity Team with role: {2}.';
    private static final String CHATTER_TPL_ROLE = '{0} updated {1}\'s role in the Opportunity Team to: {2}.';

    // ─────────────────────────────────────────────────────────────────────────────
    //  READ METHODS (cacheable)
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Retrieves the list of Opportunity Team Members for a given Opportunity.
     *              Used by the LWC to populate the "Current Members" tab.
     * @param opportunityId  Id of the Opportunity record.
     * @return               Ordered list of OpportunityTeamMember records.
     */
    @AuraEnabled(cacheable=true)
    public static List<OpportunityTeamMember> getTeamMembers(Id opportunityId) {
        return [
            SELECT Id,
                   UserId,
                   User.Name,
                   User.Email,
                   TeamMemberRole,
                   OpportunityAccessLevel
            FROM   OpportunityTeamMember
            WHERE  OpportunityId = :opportunityId
            ORDER BY User.Name ASC
        ];
    }

    /**
     * @description Retrieves active picklist values for the TeamMemberRole field.
     *              Used by the LWC combobox on the "Add Member" tab.
     * @return  List of {label, value} maps ready for lightning-combobox options.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTeamRoles() {
        List<Map<String, String>> roles = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : OpportunityTeamMember.TeamMemberRole.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                roles.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return roles;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  WRITE METHODS
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Adds a new member to the Opportunity Team with a fixed Edit access level.
     *              Validates caller authorization, target user status, and duplicate membership
     *              before delegating DML to the without-sharing inner class.
     *              Sends a Chatter post and an email notification on success.
     *
     * @param opportunityId   Id of the Opportunity.
     * @param userId          Id of the User to add.
     * @param teamMemberRole  Role to assign (optional — may be blank).
     * @throws AuraHandledException if any validation check fails.
     */
    @AuraEnabled
    public static void addTeamMember(Id opportunityId, Id userId, String teamMemberRole) {

        // ── Validation 1 : caller is a team member with Edit access ──────────────
        validateCallerAccess(opportunityId);

        // ── Validation 2 : target user is active ─────────────────────────────────
        List<User> targetUsers = [
            SELECT Id, Name, Email, IsActive
            FROM   User
            WHERE  Id = :userId
            LIMIT  1
        ];
        if (targetUsers.isEmpty() || !targetUsers[0].IsActive) {
            throw new AuraHandledException(Label.OTM_Error_UserInactive);
        }

        // ── Validation 3 : not already a team member ──────────────────────────────
        List<OpportunityTeamMember> existing = [
            SELECT Id
            FROM   OpportunityTeamMember
            WHERE  OpportunityId = :opportunityId
            AND    UserId        = :userId
            LIMIT  1
        ];
        if (!existing.isEmpty()) {
            throw new AuraHandledException(Label.OTM_Error_AlreadyMember);
        }

        // ── Fetch Opportunity name for notifications ───────────────────────────────
        Opportunity opp = [SELECT Id, Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1];

        // ── DML ───────────────────────────────────────────────────────────────────
        new OppTeamMemberDML().insertMember(opportunityId, userId, teamMemberRole);

        // ── Notifications ─────────────────────────────────────────────────────────
        User caller = getCurrentUser();
        String role = String.isNotBlank(teamMemberRole) ? teamMemberRole : '—';

        sendChatterNotification(
            opportunityId,
            String.format(CHATTER_TPL_ADD, new List<Object>{ caller.Name, targetUsers[0].Name, role })
        );
        sendEmailNotification(
            targetUsers[0].Email,
            String.format(Label.OTM_Email_Subject_Add, new List<Object>{ opp.Name }),
            buildAddEmailBody(targetUsers[0].Name, opp.Name, role, caller.Name)
        );
    }

    /**
     * @description Updates the TeamMemberRole of an existing OpportunityTeamMember record.
     *              Validates caller authorization before delegating DML to the
     *              without-sharing inner class.
     *              Sends a Chatter post and an email notification on success.
     *
     * @param teamMemberId  Id of the OpportunityTeamMember record to update.
     * @param newRole       New role value (may be blank to clear the role).
     * @throws AuraHandledException if any validation check fails.
     */
    @AuraEnabled
    public static void updateTeamMemberRole(Id teamMemberId, String newRole) {

        // ── Fetch OTM to resolve the OpportunityId for validation ─────────────────
        List<OpportunityTeamMember> otmList = [
            SELECT Id, OpportunityId, UserId, User.Name, User.Email, TeamMemberRole
            FROM   OpportunityTeamMember
            WHERE  Id = :teamMemberId
            LIMIT  1
        ];
        if (otmList.isEmpty()) {
            throw new AuraHandledException(Label.OTM_Error_NotFound);
        }
        OpportunityTeamMember otm = otmList[0];

        // ── Validation : caller authorization ─────────────────────────────────────
        validateCallerAccess(otm.OpportunityId);

        // ── Fetch Opportunity name for notifications ───────────────────────────────
        Opportunity opp = [SELECT Id, Name FROM Opportunity WHERE Id = :otm.OpportunityId LIMIT 1];

        // ── DML ───────────────────────────────────────────────────────────────────
        new OppTeamMemberDML().updateRole(teamMemberId, newRole);

        // ── Notifications ─────────────────────────────────────────────────────────
        User caller = getCurrentUser();
        String role = String.isNotBlank(newRole) ? newRole : '—';

        sendChatterNotification(
            otm.OpportunityId,
            String.format(CHATTER_TPL_ROLE, new List<Object>{ caller.Name, otm.User.Name, role })
        );
        sendEmailNotification(
            otm.User.Email,
            String.format(Label.OTM_Email_Subject_Role, new List<Object>{ opp.Name }),
            buildRoleEmailBody(otm.User.Name, opp.Name, role, caller.Name)
        );
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  PRIVATE — VALIDATION
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Validates that the current user is an OpportunityTeamMember
     *              with OpportunityAccessLevel = Edit on the given Opportunity.
     *              No profile or permission set restriction applies (v1).
     *
     * @param opportunityId  Id of the Opportunity to validate against.
     * @throws AuraHandledException if the condition is not met.
     */
    private static void validateCallerAccess(Id opportunityId) {
        List<OpportunityTeamMember> membership = [
            SELECT Id, OpportunityAccessLevel
            FROM   OpportunityTeamMember
            WHERE  OpportunityId = :opportunityId
            AND    UserId        = :UserInfo.getUserId()
            LIMIT  1
        ];
        if (membership.isEmpty() || membership[0].OpportunityAccessLevel != ACCESS_LEVEL_EDIT) {
            throw new AuraHandledException(Label.OTM_Error_NotTeamMemberEdit);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  PRIVATE — NOTIFICATIONS
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Posts a Chatter FeedItem on the Opportunity record.
     *              Uses ConnectApi to support proper mention formatting.
     *              Failures are caught and logged — they do not block the main operation.
     *
     * @param opportunityId  Subject record Id.
     * @param message        Plain-text message to post.
     */
    private static void sendChatterNotification(Id opportunityId, String message) {
        try {
            ConnectApi.TextSegmentInput textSeg  = new ConnectApi.TextSegmentInput();
            textSeg.text = message;

            ConnectApi.MessageBodyInput msgBody  = new ConnectApi.MessageBodyInput();
            msgBody.messageSegments = new List<ConnectApi.MessageSegmentInput>{ textSeg };

            ConnectApi.FeedItemInput feedInput   = new ConnectApi.FeedItemInput();
            feedInput.body            = msgBody;
            feedInput.feedElementType = ConnectApi.FeedElementType.FeedItem;
            feedInput.subjectId       = opportunityId;

            ConnectApi.ChatterFeeds.postFeedElement(null, feedInput);
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'OppTeamMemberController.sendChatterNotification — ' + e.getMessage()
            );
        }
    }

    /**
     * @description Sends a single HTML email to the specified recipient.
     *              Placed in the with-sharing context (after DML) as required by
     *              Messaging.sendEmail() constraints.
     *              Failures are caught and logged — they do not block the main operation.
     *
     * @param recipientEmail  Recipient email address.
     * @param subject         Email subject line.
     * @param htmlBody        HTML body content.
     */
    private static void sendEmailNotification(String recipientEmail, String subject, String htmlBody) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ recipientEmail });
            mail.setSubject(subject);
            mail.setHtmlBody(htmlBody);
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'OppTeamMemberController.sendEmailNotification — ' + e.getMessage()
            );
        }
    }

    /**
     * @description Builds the HTML body for the "member added" notification email.
     */
    private static String buildAddEmailBody(
        String memberName,
        String oppName,
        String role,
        String addedBy
    ) {
        return '<p>Hello ' + memberName + ',</p>'
            + '<p>You have been added to the Opportunity Team for <strong>' + oppName + '</strong>'
            + (role != '—' ? ' with the role <strong>' + role + '</strong>' : '') + '.</p>'
            + '<p>Added by: <strong>' + addedBy + '</strong></p>'
            + '<p>The Salesforce Team</p>';
    }

    /**
     * @description Builds the HTML body for the "role updated" notification email.
     */
    private static String buildRoleEmailBody(
        String memberName,
        String oppName,
        String newRole,
        String updatedBy
    ) {
        return '<p>Hello ' + memberName + ',</p>'
            + '<p>Your role on the Opportunity <strong>' + oppName + '</strong>'
            + ' has been updated to <strong>' + newRole + '</strong>.</p>'
            + '<p>Updated by: <strong>' + updatedBy + '</strong></p>'
            + '<p>The Salesforce Team</p>';
    }

    /** @description Returns the current running user with Name field populated. */
    private static User getCurrentUser() {
        return [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    }

    // ─────────────────────────────────────────────────────────────────────────────
    //  INNER CLASS — DML without sharing
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Inner class executing DML operations in a without-sharing context
     *              to bypass the OWD Private restriction on OpportunityTeamMember.
     *
     *              IMPORTANT: This class must only be called AFTER all business
     *              validations have been performed in the outer with-sharing class.
     *              Its scope is intentionally minimal — insert and update on OTM only.
     */
    private without sharing class OppTeamMemberDML {

        /**
         * @description Inserts a new OpportunityTeamMember with Edit access.
         * @param oppId   Opportunity Id.
         * @param userId  User Id to add.
         * @param role    TeamMemberRole value (may be blank).
         */
        public void insertMember(Id oppId, Id userId, String role) {
            insert new OpportunityTeamMember(
                OpportunityId          = oppId,
                UserId                 = userId,
                TeamMemberRole         = role,
                OpportunityAccessLevel = 'Edit'
            );
        }

        /**
         * @description Updates the TeamMemberRole of an existing OTM record.
         * @param otmId    OpportunityTeamMember Id.
         * @param newRole  New role value.
         */
        public void updateRole(Id otmId, String newRole) {
            update new OpportunityTeamMember(
                Id             = otmId,
                TeamMemberRole = newRole
            );
        }
    }
}