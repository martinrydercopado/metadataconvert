@isTest
private class JobStartAndTrackTest {
    @isTest
    static void jobProgressTest() {
        copado__Environment__c env = new copado__Environment__c(
            Name = 'copado-unit-test'
        );
        insert env;

        copado__JobTemplate__c template = new copado__JobTemplate__c(Name='copado_sfcc_job', copado__Version__c=1);
        insert template;

        copado__JobExecution__c jobExecution = new copado__JobExecution__c(
            copado__Template__c = template.Id
        );
        insert jobExecution;

        copado__JobStep__c jobStep = new copado__JobStep__c(
            copado__JobExecution__c = jobExecution.Id,
            copado__Type__c = 'Manual',
            copado__JobTemplate__c = template.Id
            // copado__PipelineId__c = pipeline.Id
        );
        insert jobStep;

        copado__Result__c res = new copado__Result__c(
            copado__JobStep__c = jobStep.Id,
            copado__Job_Type__c = 'Integration'
        );
        insert res;

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

        String[] ids = new List<String>{jobExecution.Id};
        copado__Result__c[] results = JobStartAndTrack.jobProgress(ids);

        System.assert(results.size() == 1);
    }

    @isTest
    static void executeJobTest() {
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

            JobStartAndTrack.executeJob(story.Id);
            System.debug(story);
        }
    }
}