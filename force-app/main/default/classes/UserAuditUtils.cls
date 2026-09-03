/**
 * UserAuditUtils
 * 
 * Functions to support the creation and maintenance of User_Licence_Audit__c records
 * 
 * Author : Bernard Price (Brightgen)
 * Created: 2022-10-14
 * 
 * Changes:
 */
public inherited sharing class UserAuditUtils 
{
    // CONSTANTS
    @TestVisible
    private final static String UNIT_TEST_USERNAME_BASE = 'UAUTILSTEST';
    private final static String LOGIN_VALID = 'Success';
    private final static String PERIOD_DAILY = 'Daily';
    private final static String PERIOD_MONTHLY = 'Monthly';
    private final static String PERIOD_ANNUAL = 'Annual';
    private final static String BREAKDOWN_BY_MONTH = 'Monthly';
    private final static String BREAKDOWN_BY_QUARTER = 'Quarterly';
    private final static String BREAKDOWN_BY_YEAR = 'Annual';
    private final static String BREAKDOWN_BY_NONE = 'NONE';
    private final static Map<Integer, Integer> QUARTER_MAP = new Map<Integer, Integer>{
        1 => 1,
        2 => 1,
        3 => 1,
        4 => 2,
        5 => 2,
        6 => 2,
        7 => 3,
        8 => 3,
        9 => 3,
        10 => 4,
        11 => 4,
        12 => 4
    };
    @TestVisible
    private final static String CORPORATE_CURRENCY = 'EUR';

    //// CACHE ////
    // Transaction-scope store of the metadata costing table and other settings
    // We expect potentially multiple costs for different licence per period type
    // But only 1 active dated cost per licence type on any run date
    private static Map<String, List<Dated_User_Licence_Cost__mdt>> cachedCostsByPeriodType;
    private static Map<String, Dated_User_Licence_Cost__mdt> cachedCostsByLicenceType;
    private static Map<String, Boolean> cachedProfileLicenceIndicatorByLicenceType;
    private static Map<String, String> cachedUserFieldAPINamesByFeatureLicenceType;
    private static Boolean processDateEndOfPeriodForBreakdowns;

    // For unit test only
    @TestVisible
    private static Set<Date> forceCommunitiesLoginDates = new Set<Date>();

    //// PUBLIC METHODS ////

    /**
     * processUsersForDailyLicenceAudit
     * 
     * Perform all necessary creation/update/deletion of audit records based on the users' licence state
     */
    public static void processUsersForDailyLicenceAudit(Date processDate, List<User> users)
    {
        // Get all information from the DB
        Map<String, List<Dated_User_Licence_Cost__mdt>> costsByPeriodType = getAllCostsByPeriodType(processDate);
        Map<String, Dated_User_Licence_Cost__mdt> costsByLicenceType = getAllCostsByLicenceType(processDate);
        Map<String, Boolean> profileLicenceIndicatorByLicenceType = getProfileLicenceIndicators(processDate);
        Map<String, String> allCostedFeatureLicencesWithUserFieldAPINames = getUserFieldAPINamesByFeatureLicenceType(processDate);
        Set<String> allCostedPermSetLicences = new Set<String>();
        for (String licenceType : profileLicenceIndicatorByLicenceType.keySet())
        {
            if (!profileLicenceIndicatorByLicenceType.get(licenceType))
            {
                allCostedPermSetLicences.add(licenceType);
            }
        }
        Set<Id> userIds = new Set<Id>();
        for (user u : users)
        {
            userIds.add(u.Id);
        }
        Map<Id, List<LoginHistory>> loginsByUserId = getLoginHistoriesByUserId(processDate, userIds);
        Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId = getUserLicenceAuditsByUserId(processDate, userIds);
        // Collections for DML later
        List<User_Licence_Audit__c> auditsToInsert = new List<User_Licence_Audit__c>();
        Map<Id, User_Licence_Audit__c> auditsToUpdate = new Map<Id, User_Licence_Audit__c>();
        Map<Id, User_Licence_Audit__c> auditsToDelete = new Map<Id, User_Licence_Audit__c>();
        for (User u : users)
        {
            Boolean active = u.IsActive;
            String mainLicence = u.Profile.UserLicense.Name;
            Boolean loginBasedLicence = isLicenceLoginBased(mainLicence, costsByLicenceType);
            Boolean loggedInToday = userLoggedInOnProcessDate(processDate, u, loginsByUserId);
            Set<String> activePermissionSetLicences = getPermissionSetLicenceNames(u);
            Dated_User_Licence_Cost__mdt mainLicenceCost = costsByLicenceType.get(mainLicence);
            // Is the user actually active
            if (active)
            {
                // Is the user profile licence one that is costed/tracked
                if (mainLicenceCost != null)
                {
                    // Handle e.g. Communities login-based licences vs 'normal' or internal ones
                    if (loginBasedLicence)
                    {
                        processLoginBasedLicence(u, processDate, loggedInToday, mainLicence, mainLicenceCost, existingAuditsByUserId, auditsToInsert, auditsToUpdate);
                    }
                    else
                    {
                        processMainLicence(u, processDate, mainLicence, mainLicenceCost, existingAuditsByUserId, auditsToInsert, auditsToUpdate, auditsToDelete);
                    }
                }
                // Handle permission set licences
                processPermissionSetLicences(u, processDate, allCostedPermSetLicences, activePermissionSetLicences, costsByLicenceType, existingAuditsByUserId, auditsToInsert, auditsToUpdate, auditsToDelete);
                // Handle feature licences
                processFeatureLicences(u, processDate, allCostedFeatureLicencesWithUserFieldAPINames, costsByLicenceType, existingAuditsByUserId, auditsToInsert, auditsToUpdate, auditsToDelete);
            }
            else
            {
                // User is no longer active so close off all open audits
                List<User_Licence_Audit__c> audits = getOpenAudits(u, existingAuditsByUserId);
                for (User_Licence_Audit__c audit : audits)
                {
                    closeAudit(audit, processDate, auditsToUpdate, auditsToDelete);
                }
            }
        }
        // Update all audit records
        performDML(auditsToInsert, auditsToUpdate, auditsToDelete);
    }

    /**
     * closeUserLicenceAudits
     * 
     * Sets the end date of all the provided audit records to the process date
     */
    public static List<User_Licence_Audit__c> closeUserLicenceAudits(Date processDate, List<User_Licence_Audit__c> audits)
    {
        for (User_Licence_Audit__c audit : audits)
        {
            audit.End_Date__c = processDate;
        }
        performDML(null, new Map<Id, User_Licence_Audit__c>(audits), null);
        return audits;
    }

    /**
     * isProcessDateEndOfPeriodForBreakdowns
     * 
     * Returns true if the process date is the last date in e.g. the Quarter if the audits should be broken down by quarter
     * regardless of periods of continous activity (for reporting purposes)
     */
    public static Boolean isProcessDateEndOfPeriodForBreakdowns(Date processDate)
    {
        if (processDateEndOfPeriodForBreakdowns == null)
        {
            String setting = getPeriodBreakdownSetting(); 
            if (setting == BREAKDOWN_BY_NONE)
            {
                processDateEndOfPeriodForBreakdowns = false;
            }
            else if (setting == BREAKDOWN_BY_MONTH && (processDate.month() != processDate.addDays(1).month()))
            {
                processDateEndOfPeriodForBreakdowns = true;
            }
            else if (setting == BREAKDOWN_BY_QUARTER && (QUARTER_MAP.get(processDate.month()) != QUARTER_MAP.get(processDate.addDays(1).month())))
            {
                processDateEndOfPeriodForBreakdowns = true;
            }
            else if (setting == BREAKDOWN_BY_YEAR && (processDate.year() != processDate.addDays(1).year()))
            {
                processDateEndOfPeriodForBreakdowns = true;
            }
            else
            {
                processDateEndOfPeriodForBreakdowns = false;
            }
        }
        return processDateEndOfPeriodForBreakdowns;
    }

    /**
     * getUsersForDailyLicenceAudit
     * 
     * Returns a list of active or recently active users based on the process date
     */
    public static List<User> getUsersForDailyLicenceAudit(Date processDate)
    {
        // This date needs to be used to capture changes made to the user record in real time and allow for the job running past midnight
        Date systemDate = System.Today().addDays(-1);
        String queryString = 'SELECT Id, IsActive, LastLoginDate, Profile.UserLicense.Name, ';
        queryString += '(SELECT Id,PermissionSetLicense.MasterLabel FROM PermissionSetLicenseAssignments) ';
        queryString += getAdditionalUserFieldsForDailyLicenceAuditQuery(processDate);
        queryString += 'FROM User ';
        queryString += 'WHERE Profile.UserLicenseId <> null ';
        queryString += 'AND (IsActive = true OR LastModifiedDate >= :systemDate) ';
        if (Test.isRunningTest())
        {
            String partialUsernameFilter = '\'' + String.escapeSingleQuotes(UNIT_TEST_USERNAME_BASE.trim()) + '%\'';
            queryString += 'AND Username LIKE ' + partialUsernameFilter + ' ';
        }
        queryString += 'ORDER BY LastModifiedDate DESC';
        return Database.query(queryString);
    }

    /**
     * getUserLicenceAuditsForPeriodicClosure
     * 
     * Returns a list of audit records that are still open as of the process date
     */
    public static List<User_Licence_Audit__c> getUserLicenceAuditsForPeriodicClosure(Date processDate)
    {
        return [SELECT Id, User__c, Start_Date__c, End_Date__c 
                FROM User_Licence_Audit__c 
                WHERE Start_Date__c <= :processDate 
                AND End_Date__c = null 
                ORDER BY Start_Date__c DESC];
    }

    //// PRIVATE METHODS ////

    /**
     * getUserLicenceAuditsByUserId
     * 
     * Returns a collection of open or recently closed audit records based on the process date
     */
    private static Map<Id, List<User_Licence_Audit__c>> getUserLicenceAuditsByUserId(Date processDate, Set<Id> userIds)
    {
        Map<Id, List<User_Licence_Audit__c>> ualsByUserId = new Map<Id, List<User_Licence_Audit__c>>();
        List<User_Licence_Audit__c> ualsFromQuery;
        // If this is e.g. the start of a quarter, don't include audits that were closed at the end of last
        // This will prevent them being inadvertently re-opened based on continous acivity where it would
        // cross the breakdown boundary
        if (isProcessDateEndOfPeriodForBreakdowns(processDate.addDays(-1)))
        {
            ualsFromQuery = [SELECT Id,User__c,Start_Date__c,End_Date__c,Licence_Type__c,User_Profile_Licence__c,Cost__c,Cost_Period__c 
                             FROM User_Licence_Audit__c 
                             WHERE User__c IN :userIds 
                             AND Start_Date__c <= :processDate 
                             AND (End_Date__c = null) 
                             ORDER BY Start_Date__c DESC];
        }
        else
        {
            Date yesterday = processDate.addDays(-1);
            Date endOfLastMonth = processDate.toStartOfMonth().addDays(-1);
            Date endOfLastYear = Date.newInstance(processDate.year() - 1, 12, 31);
            ualsFromQuery = [SELECT Id,User__c,Start_Date__c,End_Date__c,Licence_Type__c,User_Profile_Licence__c,Cost__c,Cost_Period__c 
                             FROM User_Licence_Audit__c 
                             WHERE User__c IN :userIds 
                             AND Start_Date__c <= :processDate 
                             AND (End_Date__c = null 
                                OR End_Date__c >= :yesterday 
                                OR (Activity_Based_On_Login__c = true AND Cost_Period__c = 'Monthly' AND End_Date__c = :endOfLastMonth) 
                                OR (Activity_Based_On_Login__c = true AND Cost_Period__c = 'Annual' AND End_Date__c = :endOfLastYear) 
                             ) 
                             ORDER BY Start_Date__c DESC];
        }
        for (User_Licence_Audit__c ual : ualsFromQuery)
        {
            if (!ualsByUserId.containsKey(ual.User__c))
            {
                ualsByUserId.put(ual.User__c, new List<User_Licence_Audit__c>());
            }
            ualsByUserId.get(ual.User__c).add(ual);
        }
        return ualsByUserId;
    }

    /**
     * getLoginHistoriesByUserId
     * 
     * Returns a collection of login history records for the process date and user IDs provided
     */
    @TestVisible
    private static Map<Id, List<LoginHistory>> getLoginHistoriesByUserId(Date processDate, Set<Id> userIds)
    {
        Map<Id, List<LoginHistory>> loginsByUserId = new Map<Id, List<LoginHistory>>();
        for (LoginHistory loginHistory : [SELECT Id,UserId,LoginTime,Status 
                                          FROM LoginHistory 
                                          WHERE UserId IN :userIds 
                                          AND DAY_ONLY(LoginTime) = :processDate 
                                          ORDER BY LoginTime DESC])
        {
            // Status cannot be filtered in SOQL so check here
            if (loginHistory.Status == LOGIN_VALID)
            {
                if (!loginsByUserId.containsKey(loginHistory.UserId))
                {
                    loginsByUserId.put(loginHistory.UserId, new List<LoginHistory>());
                }
                loginsByUserId.get(loginHistory.UserId).add(loginHistory);
            }
        }
        return loginsByUserId;
    }

    /**
     * processLoginBasedLicence
     * 
     * Perform updates to audit records for this User that has a login-based main licence
     */
    private static void processLoginBasedLicence(User u, Date processDate, Boolean loggedInToday, String mainLicence, Dated_User_Licence_Cost__mdt cost, Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId, 
        List<User_Licence_Audit__c> auditsToInsert, Map<Id, User_Licence_Audit__c> auditsToUpdate)
    {
        if (loggedInToday)
        {
            Date loginPeriodStartDate;
            Date loginPeriodEndDate;
            if (cost.Cost_Period__c == PERIOD_DAILY)
            {
                loginPeriodStartDate = processDate;
                loginPeriodEndDate = processDate;
            }
            else if (cost.Cost_Period__c == PERIOD_MONTHLY)
            {
                loginPeriodStartDate = processDate.toStartOfMonth();
                loginPeriodEndDate = loginPeriodStartDate.addMonths(1).addDays(-1);
            }
            else if (cost.Cost_Period__c == PERIOD_ANNUAL)
            {
                loginPeriodStartDate = Date.newInstance(processDate.year(), 1, 1);
                loginPeriodEndDate = Date.newInstance(processDate.year(), 12, 31);
                
            }
            else
            {
                System.debug(LoggingLevel.ERROR, 'Unexpected Cost Period: ' + cost.Cost_Period__c);
                return;
            }
            User_Licence_Audit__c lastLoginPeriodAudit = getImmediatelyPreviousLoginAudit(processDate, u, mainLicence, true, cost, existingAuditsByUserId);
            if (lastLoginPeriodAudit != null && auditAndCostSettingsMatch(lastLoginPeriodAudit, cost))
            {
                // Update yesterday's closed one to track consecutive logins without too many records
                extendAudit(lastLoginPeriodAudit, loginPeriodEndDate, auditsToUpdate);
            }
            else
            {
                // Get closed audit surrounding the process date
                User_Licence_Audit__c currentLoginAudit = getCurrentLoginAudit(processDate, u, mainLicence, true, existingAuditsByUserId);
                if (currentLoginAudit == null)
                {
                    // If it does NOT exist, create it, else do nothing
                    createAudit(u, cost, loginPeriodStartDate, loginPeriodEndDate, true, auditsToInsert);
                }
            }
        } // if there was no login today there is nothing to do, the last login audit was created as closed
    }

    /**
     * processMainLicence
     * 
     * Perform updates to audit records for this User with this profile licence
     */
    private static void processMainLicence(User u, Date processDate, String mainLicence, Dated_User_Licence_Cost__mdt cost, Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId, 
        List<User_Licence_Audit__c> auditsToInsert, Map<Id, User_Licence_Audit__c> auditsToUpdate, Map<Id, User_Licence_Audit__c> auditsToDelete)
    {
        User_Licence_Audit__c openAudit = getCurrentlyOpenAudit(processDate, u, mainLicence, true, existingAuditsByUserId);
        if (openAudit == null)
        {
            User_Licence_Audit__c openAuditDifferentLicence = getCurrentlyOpenAudit(processDate, u, null, true, existingAuditsByUserId);
            if (openAuditDifferentLicence != null)
            {
                // Close the other licence type and create a new one for this type
                // We need to close it a day early so there isn't an overlap
                // e.g. create a user with licence A then same day switch it to licence B, that is effectively 0 days for licence A
                closeAudit(openAuditDifferentLicence, processDate.addDays(-1), auditsToUpdate, auditsToDelete);
            }
            else
            {
                User_Licence_Audit__c yesterdaysAudit = getAuditClosedYesterday(processDate, u, mainLicence, true, existingAuditsByUserId);
                if (yesterdaysAudit != null && auditAndCostSettingsMatch(yesterdaysAudit, cost))
                {
                    // Update yesterday's closed one to take the end date back off
                    reopenAudit(yesterdaysAudit, auditsToUpdate);
                }
                else
                {
                    // Create a new one
                    createAudit(u, cost, processDate, null, true, auditsToInsert);
                }
            }
        }
        else
        {
            // Close and create a new audit if the cost has been changed
            if (!auditAndCostSettingsMatch(openAudit, cost))
            {
                closeAudit(openAudit, processDate.addDays(-1), auditsToUpdate, auditsToDelete);
                createAudit(u, cost, processDate, null, true, auditsToInsert);
            }
        }
    }

    /**
     * processPermissionSetLicences
     * 
     * Perform updates to audit records for this User for any applicable permission set licences
     */
    private static void processPermissionSetLicences(User u, Date processDate, Set<String> allCostedPermSetLicences, Set<String> activePermissionSetLicences, Map<String, Dated_User_Licence_Cost__mdt> costsByLicenceType, 
        Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId, List<User_Licence_Audit__c> auditsToInsert, Map<Id, User_Licence_Audit__c> auditsToUpdate, Map<Id, User_Licence_Audit__c> auditsToDelete)
    {
        // For everything in the active set, similar to logic for active main          
        for (String userPermSetLicence : activePermissionSetLicences)
        {
            Dated_User_Licence_Cost__mdt cost = costsByLicenceType.get(userPermSetLicence);
            if (cost != null)
            {
                User_Licence_Audit__c openAudit = getCurrentlyOpenAudit(processDate, u, userPermSetLicence, false, existingAuditsByUserId);
                if (openAudit == null)
                {
                    User_Licence_Audit__c yesterdaysAudit = getAuditClosedYesterday(processDate, u, userPermSetLicence, false, existingAuditsByUserId);
                    if (yesterdaysAudit != null && auditAndCostSettingsMatch(yesterdaysAudit, cost))
                    {
                        // Update yesterday's closed one to take the end date back off
                        reopenAudit(yesterdaysAudit, auditsToUpdate);
                    }
                    else
                    {
                        // Create a new one
                        createAudit(u, cost, processDate, null, false, auditsToInsert);
                    }
                }
                else
                {
                    // Close and create a new audit if the cost has been changed
                    if (!auditAndCostSettingsMatch(openAudit, cost))
                    {
                        closeAudit(openAudit, processDate.addDays(-1), auditsToUpdate, auditsToDelete);
                        createAudit(u, cost, processDate, null, true, auditsToInsert);
                    }
                }
            }
        }
        // For everything that is currently open audit, if not in the active set then close
        List<User_Licence_Audit__c> audits = getOpenAudits(u, existingAuditsByUserId);
        for (User_Licence_Audit__c audit : audits)
        {
            if (allCostedPermSetLicences.contains(audit.Licence_Type__c))
            {
                if (!activePermissionSetLicences.contains(audit.Licence_Type__c))
                {
                    closeAudit(audit, processDate, auditsToUpdate, auditsToDelete);
                }
            }
        }
    }

    private static void processFeatureLicences(User u, Date processDate, Map<String, String> allCostedFeatureLicencesWithUserFieldAPINames, Map<String, Dated_User_Licence_Cost__mdt> costsByLicenceType, 
        Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId, List<User_Licence_Audit__c> auditsToInsert, Map<Id, User_Licence_Audit__c> auditsToUpdate, Map<Id, User_Licence_Audit__c> auditsToDelete)
    {
        Set<String> activeFeatureLicences = new Set<String>();
        for (String featureLicenceType : allCostedFeatureLicencesWithUserFieldAPINames.keySet())
        {
            String featureLicenceField = allCostedFeatureLicencesWithUserFieldAPINames.get(featureLicenceType);
            if ((Boolean) u.get(featureLicenceField) == true)
            {
                activeFeatureLicences.add(featureLicenceType);
            }
        }
        for (String featureLicenceType : activeFeatureLicences)
        {
            Dated_User_Licence_Cost__mdt cost = costsByLicenceType.get(featureLicenceType);
            if (cost != null)
            {
                User_Licence_Audit__c openAudit = getCurrentlyOpenAudit(processDate, u, featureLicenceType, false, existingAuditsByUserId);
                if (openAudit == null)
                {
                    User_Licence_Audit__c yesterdaysAudit = getAuditClosedYesterday(processDate, u, featureLicenceType, false, existingAuditsByUserId);
                    if (yesterdaysAudit != null && auditAndCostSettingsMatch(yesterdaysAudit, cost))
                    {
                        // Update yesterday's closed one to take the end date back off
                        reopenAudit(yesterdaysAudit, auditsToUpdate);
                    }
                    else
                    {
                        // Create a new one
                        createAudit(u, cost, processDate, null, false, auditsToInsert);
                    }
                }
                else
                {
                    // Close and create a new audit if the cost has been changed
                    if (!auditAndCostSettingsMatch(openAudit, cost))
                    {
                        closeAudit(openAudit, processDate.addDays(-1), auditsToUpdate, auditsToDelete);
                        createAudit(u, cost, processDate, null, true, auditsToInsert);
                    }
                }
            }
        }
        // For everything that is currently open audit, if not in the active set then close
        List<User_Licence_Audit__c> audits = getOpenAudits(u, existingAuditsByUserId);
        for (User_Licence_Audit__c audit : audits)
        {
            if (allCostedFeatureLicencesWithUserFieldAPINames.keySet().contains(audit.Licence_Type__c))
            {
                if (!activeFeatureLicences.contains(audit.Licence_Type__c))
                {
                    closeAudit(audit, processDate, auditsToUpdate, auditsToDelete);
                }
            }
        }
    }

    /**
     * isLicenceLoginBased
     * 
     * Returns true if this licence type is login-based
     */
    private static Boolean isLicenceLoginBased(String licenceName, Map<String, Dated_User_Licence_Cost__mdt> costsByLicenceType)
    {
        return costsByLicenceType.containsKey(licenceName) && costsByLicenceType.get(LicenceName).Activity_Based_On_Login__c;
    }

    /**
     * userLoggedInOnProcessDate
     * 
     * Returns true if there is a successful login history record for this user on the process date
     */
    private static Boolean userLoggedInOnProcessDate(Date processDate, User u, Map<Id, List<LoginHistory>> loginsByUser)
    {
        // Allow a unit test to pretend a newly created test user has logged in since we can't create the history
        if (Test.isRunningTest() && forceCommunitiesLoginDates.contains(processDate))
        {
            return true;
        }
        // We assume the query has found anything for the process date already, so just check if there are any logins
        return loginsByUser.containsKey(u.Id) && loginsByUser.get(u.Id).size() > 0;
    }

    /**
     * getPermissionSetLicenceNames
     * 
     * Returns a collection of unique permission set licence names assigned to the specified user
     */
    private static Set<String> getPermissionSetLicenceNames(User u)
    {
        Set<String> uniqueLicences = new Set<String>();
        if (u.PermissionSetLicenseAssignments != null)
        {
            for (PermissionSetLicenseAssign licenceAssign : u.PermissionSetLicenseAssignments)
            {
                uniqueLicences.add(licenceAssign.PermissionSetLicense.MasterLabel);
            }
        }
        return uniqueLicences;
    }

    /**
     * auditAndCostSettingsMatch
     * 
     * Returns true if the frequency and base cost of the custom metadata entry (still) match the existing audit record
     */
    private static Boolean auditAndCostSettingsMatch(User_Licence_Audit__c audit, Dated_User_Licence_Cost__mdt cost)
    {
        return (audit.Cost__c == cost.Cost__c) && (audit.Cost_Period__c == cost.Cost_Period__c);
    }

    /**
     * getOpenAudits
     * 
     * Returns a list of audit records that are still open against the specified user
     */
    private static List<User_Licence_Audit__c> getOpenAudits(User u, Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId)
    {
        List<User_Licence_Audit__c> openAudits = new List<User_Licence_Audit__c>();
        if (existingAuditsByUserId.containsKey(u.Id))
        {
            for (User_Licence_Audit__c audit : existingAuditsByUserId.get(u.Id))
            {
                if (audit.End_Date__c == null)
                {
                    openAudits.add(audit);
                }
            }
        }
        return openAudits;
    }

    /**
     * getCurrentlyOpenAudit
     * 
     * Returns a the single audit record that is still open against the specified user, matching the licence type or profile licence indicator
     */
    private static User_Licence_Audit__c getCurrentlyOpenAudit(Date processDate, User u, String licenceType, Boolean mainLicence, Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId)
    {
        if (existingAuditsByUserId.containsKey(u.Id))
        {
            for (User_Licence_Audit__c audit : existingAuditsByUserId.get(u.Id))
            {
                if ((licenceType != null && audit.Licence_Type__c == licenceType) 
                    || (licenceType == null && mainLicence && audit.User_Profile_Licence__c))
                {
                    if (audit.End_Date__c == null)
                    {
                        return audit;
                    }
                }
            }
        }
        return null;
    }

    /**
     * getAuditClosedYesterday
     * 
     * Returns a the single audit record that was closed yesterday against the specified user, matching the licence type or profile licence indicator
     */
    private static User_Licence_Audit__c getAuditClosedYesterday(Date processDate, User u, String licenceType, Boolean mainLicence, Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId)
    {
        if (existingAuditsByUserId.containsKey(u.Id))
        {
            for (User_Licence_Audit__c audit : existingAuditsByUserId.get(u.Id))
            {
                if ((licenceType != null && audit.Licence_Type__c == licenceType) 
                    || (licenceType == null && mainLicence && audit.User_Profile_Licence__c))
                {
                    if (audit.End_Date__c == processDate.addDays(-1))
                    {
                        return audit;
                    }
                }
            }
        }
        return null;
    }

    /**
     * getCurrentLoginAudit
     * 
     * Returns a the single audit record that opens and closes around the process date against the specified user, matching the licence type or profile licence indicator
     */
    private static User_Licence_Audit__c getCurrentLoginAudit(Date processDate, User u, String licenceType, Boolean mainLicence, Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId)
    {
        if (existingAuditsByUserId.containsKey(u.Id))
        {
            for (User_Licence_Audit__c audit : existingAuditsByUserId.get(u.Id))
            {
                if ((licenceType != null && audit.Licence_Type__c == licenceType) 
                    || (licenceType == null && mainLicence && audit.User_Profile_Licence__c))
                {
                    if (audit.Start_Date__c <= processDate && audit.End_Date__c >= processDate)
                    {
                        return audit;
                    }
                }
            }
        }
        return null;
    }

    /**
     * getImmediatelyPreviousLoginAudit
     * 
     * Returns a the single audit record that was closed just before this login period against the specified user, matching the licence type or profile licence indicator
     */
    private static User_Licence_Audit__c getImmediatelyPreviousLoginAudit(Date processDate, User u, String licenceType, Boolean mainLicence, Dated_User_Licence_Cost__mdt cost, Map<Id, List<User_Licence_Audit__c>> existingAuditsByUserId)
    {
        if (existingAuditsByUserId.containsKey(u.Id))
        {
            for (User_Licence_Audit__c audit : existingAuditsByUserId.get(u.Id))
            {
                if ((licenceType != null && audit.Licence_Type__c == licenceType) 
                    || (licenceType == null && mainLicence && audit.User_Profile_Licence__c))
                {
                    if (cost.Cost_Period__c == PERIOD_DAILY && audit.End_Date__c == processDate.addDays(-1))
                    {
                        return audit;
                    }
                    if (cost.Cost_Period__c == PERIOD_MONTHLY && audit.End_Date__c == processDate.toStartOfMonth().addDays(-1))
                    {
                        return audit;
                    }
                    if (cost.Cost_Period__c == PERIOD_ANNUAL && audit.End_Date__c == Date.newInstance(processDate.year() - 1, 12, 31))
                    {
                        return audit;
                    }
                }
            }
        }
        return null;
    }

    /**
     * createAudit
     * 
     * Create a new audit record with the details provided
     */
    private static User_Licence_Audit__c createAudit(User u, Dated_User_Licence_Cost__mdt cost, Date startDate, Date endDate, Boolean profileLicence, List<User_Licence_Audit__c> auditsToInsert)
    {
        User_Licence_Audit__c audit = new User_Licence_Audit__c();
        audit.User__c = u.Id;
        audit.User_Profile_Licence__c = profileLicence;
        audit.Feature_Licence__c = cost.Feature_Licence__c;
        audit.Activity_Based_On_Login__c = cost.Activity_Based_On_Login__c;
        audit.Start_Date__c = startDate;
        audit.End_Date__c = endDate;
        audit.Licence_Type__c = cost.Licence_Type__c;
        audit.Cost_Period__c = cost.Cost_Period__c;
        audit.Cost__c = cost.Cost__c;
        audit.CurrencyISOCode = CORPORATE_CURRENCY;
        auditsToInsert.add(audit);
        return audit;
    }

    /**
     * closeAudit
     * 
     * Close the audit record by setting its end date or potentially by removing it
     */
    private static void closeAudit(User_Licence_Audit__c audit, Date endDate, Map<Id, User_Licence_Audit__c> auditsToUpdate, Map<Id, User_Licence_Audit__c> auditsToDelete)
    {
        audit.End_Date__c = endDate;
        // If this is now effectively 0 days of activity just remove it
        if (audit.Start_Date__c > audit.End_Date__c)
        {
            auditsToDelete.put(audit.Id, audit);
        }
        else
        {
            auditsToUpdate.put(audit.Id, audit);
        }
    }

    /**
     * reopenAudit
     * 
     * Reopen the audit record by clearing its end date
     */
    private static void reopenAudit(User_Licence_Audit__c audit, Map<Id, User_Licence_Audit__c> auditsToUpdate)
    {
        audit.End_Date__c = null;
        auditsToUpdate.put(audit.Id, audit);
    }

    /**
     * extendAudit
     * 
     * Extend the audit record by moving its end date along to the process date
     */
    private static void extendAudit(User_Licence_Audit__c audit, Date endDate, Map<Id, User_Licence_Audit__c> auditsToUpdate)
    {
        audit.End_Date__c = endDate;
        auditsToUpdate.put(audit.Id, audit);
    }

    /**
     * performDML
     * 
     * Apply all necessary changes to the audit records to the DB
     */
    private static void performDML(List<User_Licence_Audit__c> auditsToInsert, Map<Id, User_Licence_Audit__c> auditsToUpdate, Map<Id, User_Licence_Audit__c> auditsToDelete)
    {
        if (auditsToInsert != null && auditsToInsert.size() > 0)
        {
            insert auditsToInsert;
        }
        if (auditsToUpdate != null && auditsToUpdate.size() > 0)
        {
            update auditsToUpdate.values();
        }
        if (auditsToDelete != null && auditsToDelete.size() > 0)
        {
            delete auditsToDelete.values();
        }
    }

    /**
     * getAdditionalUseFieldsForDailyLicenceAuditQuery
     * 
     * Returns a String representing the list of additional User fields 
     * to include in the SOQL
     */
    private static String getAdditionalUserFieldsForDailyLicenceAuditQuery(Date processDate)
    {
        Map<String, String> userFieldAPINamesByLicenceType = getUserFieldAPINamesByFeatureLicenceType(processDate);
        if (userFieldAPINamesByLicenceType.size() > 0)
        {
            return ',' + String.Join(userFieldAPINamesByLicenceType.values(), ',') + ' ';
        }
        return '';
    }

    /**
     * getAllCostsByPeriodType
     * 
     * Returns a collection of all entries in the cost table applicable to the process date, mapped by their period/frequency type
     */
    private static Map<String, List<Dated_User_Licence_Cost__mdt>> getAllCostsByPeriodType(Date processDate)
    {
        populateCache(processDate);
        return cachedCostsByPeriodType;
    }

    /**
     * getAllCostsByLicenceType
     * 
     * Returns a collection of all entries in the cost table applicable to the process date, mapped by their licence type
     */
    private static Map<String, Dated_User_Licence_Cost__mdt> getAllCostsByLicenceType(Date processDate)
    {
        populateCache(processDate);
        return cachedCostsByLicenceType;
    }

    /**
     * getProfileLicenceIndicators
     * 
     * Returns a map of licence type to boolean indicator of whether that type is a profile or e.g. permission set licence
     */
    private static Map<String, Boolean> getProfileLicenceIndicators(Date processDate)
    {
        populateCache(processDate);
        return cachedProfileLicenceIndicatorByLicenceType;
    }

    /**
     * getUserFieldAPINamesByFeatureLicenceType
     * 
     * Returns a map of (feature) licence type to User field API name that corresponds to it
     */
    private static Map<String, String> getUserFieldAPINamesByFeatureLicenceType(Date processDate)
    {
        populateCache(processDate);
        return cachedUserFieldAPINamesByFeatureLicenceType;
    }

    /**
     * populateCache
     * 
     * Populate all transaction-scope collections from the DB
     */
    private static void populateCache(Date processDate)
    {
        if (cachedCostsByPeriodType == null || 
            cachedCostsByLicenceType == null || 
            cachedProfileLicenceIndicatorByLicenceType == null || 
            cachedUserFieldAPINamesByFeatureLicenceType == null)
        {
            clearCache();
            // Doing this as a query rather than using the cache to immediately filter out 
            // what may be an increasing number of historic records
            // Also we must split this into 2 queries as custom metadata does not support disjunctions!
            List<Dated_User_Licence_Cost__mdt> costs = [SELECT Id, Start_Date__c, End_Date__c, Cost__c, Cost_Period__c, Licence_Type__c, User_Profile_Licence__c, 
                                                               Activity_Based_On_Login__c, Feature_Licence__c, Feature_Licence_User_Field_API_Name__c 
                                                        FROM Dated_User_Licence_Cost__mdt 
                                                        WHERE Start_Date__c <= :processDate 
                                                        AND End_Date__c = null];
            costs.addAll([SELECT Id, Start_Date__c, End_Date__c, Cost__c, Cost_Period__c, Licence_Type__c, User_Profile_Licence__c, 
                                Activity_Based_On_Login__c, Feature_Licence__c, Feature_Licence_User_Field_API_Name__c  
                          FROM Dated_User_Licence_Cost__mdt 
                          WHERE Start_Date__c <= :processDate 
                          AND End_Date__c <> null 
                          AND End_Date__c >= :processDate]);
            populateCacheMapsFromMDTs(costs);
        }
    }

    /**
     * populateCacheForUnitTest
     * 
     * Populate all transaction-scope collections with the information provided from a unit test
     */
    @TestVisible
    private static void populateCacheForUnitTest(List<Dated_User_Licence_Cost__mdt> costs)
    {
        clearCache();
        populateCacheMapsFromMDTs(costs);
    }

    /**
     * clearCache
     * 
     * Clear all cached collections in this class
     */
    private static void clearCache()
    {
        cachedCostsByPeriodType = new Map<String, List<Dated_User_Licence_Cost__mdt>>();
        cachedCostsByLicenceType = new Map<String, Dated_User_Licence_Cost__mdt>();
        cachedProfileLicenceIndicatorByLicenceType = new Map<String, Boolean>();
        cachedUserFieldAPINamesByFeatureLicenceType = new Map<String, String>();
    }

    /**
     * populateCacheMapsFromMDTs
     * 
     * Populate all transaction-scope collections with the information retrieved
     */
    private static void populateCacheMapsFromMDTs(List<Dated_User_Licence_Cost__mdt> costs)
    {
        for (Dated_User_Licence_Cost__mdt cost : costs)
        {
            // If for some reason there are duplicate costs overlapping the same run date, take the latest one
            Dated_User_Licence_Cost__mdt otherCostSameLicenceType = cachedCostsByLicenceType.get(cost.Licence_Type__c);
            if (otherCostSameLicenceType == null || otherCostSameLicenceType.Start_Date__c < cost.Start_Date__c)
            {
                cachedCostsByLicenceType.put(cost.Licence_Type__c, cost);
            }
        }
        // Use the unique collection to populate the others
        for (Dated_User_Licence_Cost__mdt uniqueCost : cachedCostsByLicenceType.values())
        {
            String periodType = uniqueCost.Cost_Period__c;
            if (!cachedCostsByPeriodType.containsKey(periodType))
            {
                cachedCostsByPeriodType.put(periodType, new List<Dated_User_Licence_Cost__mdt>());
            }
            cachedCostsByPeriodType.get(periodType).add(uniqueCost);

            cachedProfileLicenceIndicatorByLicenceType.put(uniqueCost.Licence_Type__c, uniqueCost.User_Profile_Licence__c);

            if (uniqueCost.Feature_Licence__c)
            {
                cachedUserFieldAPINamesByFeatureLicenceType.put(uniqueCost.Licence_Type__c, uniqueCost.Feature_Licence_User_Field_API_Name__c);
            }
        }
    }

    /**
     * getPeriodBreakdownSetting
     * 
     * Returns a setting to control where the boundaries should be between forcibly
     * closed audits, to allow reporting to that level of granularity
     */
    private static String getPeriodBreakdownSetting()
    {
        // FIXME get this from a custom setting?
        // If it does become configurable, inject quarterly for unit tests
        return BREAKDOWN_BY_QUARTER;
    }
}