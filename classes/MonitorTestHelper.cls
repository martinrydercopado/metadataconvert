public with sharing class MonitorTestHelper {
    private static Boolean hasRun = false;
    @testVisible
    private static void setup() {
        if(hasRun){
            return;
        }
        hasRun = true;
        User runAsUser = createUser();
        assignPermissionSet(runAsUser.Id);
        System.runAs(runAsUser) {
            assignLicense(runAsUser.Id);
        }
    }

    private static User createUser() {
        User runAsUser = new User(
            LastName = 'UserLastName',
            Username = 'username@myemail.com',
            Email = 'username@myemail.com',
            Alias = 'MyAlias',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id, Name FROM Profile WHERE UserType = 'Standard' AND PermissionsPrivacyDataAccess = false AND PermissionsSubmitMacrosAllowed = true AND PermissionsMassInlineEdit = true LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert runAsUser;
        return runAsUser;
    }

    @testVisible
    private static User getRunAsUser() {
        List<User> runAsUsers = [SELECT Id FROM User WHERE Username = 'username@myemail.com'];
        return runAsUsers[0];
    }

    private static void assignLicense(Id userId) {
        copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
        copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();
        userLicense.isCCMEnabled = false;
        userLicense.isCopadoEnabled = true;
        userLicense.userId = userId;
        copadoGlobalAPI.upsertCopadoLicense(userLicense);
    }

    private static void assignPermissionSet(Id userId) {
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        Set<String> permissions = new Set<String>{'Copado_User', 'Copado_Functions', 'Copado_Job_Engine', 'Vlocity_EPC_Deploy'};
        for (PermissionSet permission : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permissions]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permission.Id));
        }
        insert assignments;
    }
}