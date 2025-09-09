/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class GetContentDocumentTest {
    @isTest
    static void getChangesFromUserStoryEmptyTest() {
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

        Set<String> permissions = new Set<String>{'Copado_User', 'Copado_Functions', 'Copado_Job_Engine', 'Configure_AQF'};
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for(PermissionSet permission : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permissions]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = runAsUser.Id, PermissionSetId = permission.Id));
        }
        insert assignments;

        System.runAs(runAsUser) {
            copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
            copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();
            userLicense.isCCMEnabled = true;
            userLicense.isCopadoEnabled = true;
            userLicense.userId = runAsUser.Id;
            copadoGlobalAPI.upsertCopadoLicense(userLicense);

            copado__Git_Repository__c repository = new copado__Git_Repository__c(Name='test repo');
            insert repository;

            copado__Deployment_Flow__c pipeline = new copado__Deployment_Flow__c(
                copado__Active__c=true,
                copado__Platform__c='SFCC',
                copado__Main_Branch__c='main',
                copado__Git_Repository__c=repository.Id
            );
            insert pipeline;

            copado__JobTemplate__c template = new copado__JobTemplate__c(
                Name='copado_sfcc_export_1',
                copado__ApiName__c='copado_sfcc_export_1',
                copado__Version__c=1
            );
            insert template;
            
            copado__Project__c project = new copado__Project__c(
                Name = 'copado-unit-test',
                copado__Deployment_Flow__c = pipeline.Id
            );
            insert project;

            copado__Environment__c env = new copado__Environment__c(
                Name = 'copado-unit-test'
            );
            insert env;

            copado__User_Story__c story = new copado__User_Story__c(
                copado__Environment__c = env.Id,
                copado__Project__c = project.Id
            );
            insert story;

            ContentVersion content = new ContentVersion(
                Title = 'Function Logs for run.txt',
                VersionData = Blob.valueOf('[]'),
                PathOnClient = 'logs.txt',
                Origin = 'H'
            );
            insert content;

            ContentDocumentLink links = new ContentDocumentLink(
                LinkedEntityId = env.Id,
                ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE id = :content.Id].ContentDocumentId
            );
            insert links;

            String textContent = GetContentDocument.getChangesFromUserStory(story.Id);

            System.assertEquals(textContent, '[]');
        }
    }

    @isTest
    static void getChangesFromUserStoryTest() {
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

        Set<String> permissions = new Set<String>{'Copado_User', 'Copado_Functions', 'Copado_Job_Engine', 'Configure_AQF'};
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for(PermissionSet permission : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permissions]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = runAsUser.Id, PermissionSetId = permission.Id));
        }
        insert assignments;

        System.runAs(runAsUser) {
            copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
            copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();
            userLicense.isCCMEnabled = true;
            userLicense.isCopadoEnabled = true;
            userLicense.userId = runAsUser.Id;
            copadoGlobalAPI.upsertCopadoLicense(userLicense);

            copado__Git_Repository__c repository = new copado__Git_Repository__c(Name='test repo');
            insert repository;

            copado__Deployment_Flow__c pipeline = new copado__Deployment_Flow__c(
                copado__Active__c=true,
                copado__Platform__c='SFCC',
                copado__Main_Branch__c='main',
                copado__Git_Repository__c=repository.Id
            );
            insert pipeline;

            copado__JobTemplate__c template = new copado__JobTemplate__c(
                Name='copado_sfcc_export_1',
                copado__ApiName__c='copado_sfcc_export_1',
                copado__Version__c=1
            );
            insert template;
            
            copado__Project__c project = new copado__Project__c(
                Name = 'copado-unit-test',
                copado__Deployment_Flow__c = pipeline.Id
            );
            insert project;

            copado__Environment__c env = new copado__Environment__c(
                Name = 'copado-unit-test'
            );
            insert env;

            copado__User_Story__c story = new copado__User_Story__c(
                copado__Environment__c = env.Id,
                copado__Project__c = project.Id
            );
            insert story;

            ContentVersion content = new ContentVersion(
                Title = 'metadata-cache.json',
                VersionData = Blob.valueOf('[]'),
                PathOnClient = 'logs.txt',
                Origin = 'H'
            );
            insert content;

            ContentDocumentLink links = new ContentDocumentLink(
                LinkedEntityId = env.Id,
                ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE id = :content.Id].ContentDocumentId
            );
            insert links;

            String textContent = GetContentDocument.getChangesFromUserStory(story.Id);

            System.assertEquals(textContent, '[]');
        }
    }
}