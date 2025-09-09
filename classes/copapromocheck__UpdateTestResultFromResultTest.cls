@isTest
private with sharing class UpdateTestResultFromResultTest {
    private static final String GENERIC_TOOL_NAME = '_Generic_Test_Non-QG';
    private static final String GENERIC_TOOL_NAME_QG = '_Generic_Test_-QG';
    @isTest
    private static void executeSingleTest() {
        System.runAs([SELECT Id FROM User WHERE Username = 'username@myemail.com'][0]) {
            // Setup
            copado__Result__c jobStepResult = [SELECT Id FROM copado__Result__c WHERE copado__Job_Type__c = :GENERIC_TOOL_NAME LIMIT 1];
            // Exercise 
            new UpdateTestResultFromResult().execute(null, jobStepResult, 'Success');
            // Verify
            copado__Result__c testResult = [SELECT Id, copado__Status__c, copado__Progress_Status__c, copado__Error_Message__c FROM copado__Result__c WHERE copado__Job_Type__c = '_Generic_Test_' AND copado__Test__c != null LIMIT 1];
            System.assertEquals('Success', testResult.copado__Status__c, 'The test result should not be Failed');
        }
    }
    @isTest
    private static void executeSingleTestFailure() {
        System.runAs([SELECT Id FROM User WHERE Username = 'username@myemail.com'][0]) {
            // Setup
            copado__Result__c jobStepResult = [SELECT Id FROM copado__Result__c WHERE copado__Job_Type__c = :GENERIC_TOOL_NAME LIMIT 1];
            // Exercise 
            new UpdateTestResultFromResult().execute(null, jobStepResult, 'Failed');
            // Verify
            copado__Result__c testResult = [SELECT Id, copado__Status__c, copado__Progress_Status__c, copado__Error_Message__c FROM copado__Result__c WHERE copado__Job_Type__c = '_Generic_Test_' AND copado__Test__c != null LIMIT 1];
            System.assertEquals('Failed', testResult.copado__Status__c, 'The test result should be Failed');
        }
    }
    @isTest
    private static void executeQg() {
        System.runAs([SELECT Id FROM User WHERE Username = 'username@myemail.com'][0]) {
            // Setup
            copado__Result__c jobStepResult = [SELECT Id FROM copado__Result__c WHERE copado__Job_Type__c = :GENERIC_TOOL_NAME_QG LIMIT 1];
            // Exercise 
            new UpdateTestResultFromResult().execute(null, jobStepResult, 'Success');
            // Verify
            copado__Result__c testResult = [SELECT Id, copado__Status__c, copado__Progress_Status__c, copado__Error_Message__c FROM copado__Result__c WHERE copado__Job_Type__c = '_Generic_Test_' AND copado__Test__c = null LIMIT 1];
            System.assertEquals('Success', testResult.copado__Status__c, 'The test result should not be Failed');
        }
    }
    
    @isTest
    private static void executeQgFailure() {
        System.runAs([SELECT Id FROM User WHERE Username = 'username@myemail.com'][0]) {
            // Setup
            copado__Result__c jobStepResult = [SELECT Id FROM copado__Result__c WHERE copado__Job_Type__c = :GENERIC_TOOL_NAME_QG LIMIT 1];
            // Exercise 
            new UpdateTestResultFromResult().execute(null, jobStepResult, 'Failed');
            // Verify
            copado__Result__c testResult = [SELECT Id, copado__Status__c, copado__Progress_Status__c, copado__Error_Message__c FROM copado__Result__c WHERE copado__Job_Type__c = '_Generic_Test_' AND copado__Test__c = null LIMIT 1];
            System.assertEquals('Failed', testResult.copado__Status__c, 'The test result should be Failed');
        }
    }
    @isTest
    private static void executeException() {
        System.runAs([SELECT Id FROM User WHERE Username = 'username@myemail.com'][0]) {
            //Setup
            String errorMessage = 'Attempt to de-reference a null';
            // Exercise 
            Exception ex;
            try {
                new UpdateTestResultFromResult().execute(null, null, 'Success');
            } catch (Exception e) {
                ex = e;
            }
            // Verify
            System.assertEquals(true, ex.getMessage().contains(errorMessage), 'The exception message matches.');
        }
    }
    @TestSetup
    private static void makeData() {
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

            // default values varied according to version, and what was working in 20.0 fails in 20.5 and vice-versa
            copado__ExtensionConfiguration__c extensionConfiguration;
            try{
                extensionConfiguration = new copado__ExtensionConfiguration__c(copado__Active__c = true, copado__ExtensionTool__c = 'Manual Tests', copado__ExtensionApplication__c = 'Test');
                insert extensionConfiguration;
            }catch(Exception e) {
                extensionConfiguration = new copado__ExtensionConfiguration__c(copado__Active__c = true, copado__ExtensionTool__c = 'None', copado__ExtensionApplication__c = 'Test');
                insert extensionConfiguration;
            }
            
            copado__Test__c testItem1 = new copado__Test__c(Name = '_Generic_Test_ Test - Single Execution', copado__ExtensionConfiguration__c = extensionConfiguration.Id, copado__ReadyToRun__c = true);
            copado__Test__c testItem2 = new copado__Test__c(Name = '_Generic_Test_ Test - QG Execution', copado__ExtensionConfiguration__c = extensionConfiguration.Id, copado__ReadyToRun__c = true);
            List<copado__Test__c> tests = new List<copado__Test__c>{testItem1, testItem2};
            insert tests;
            copado__Result__c testResult = new copado__Result__c(copado__Test__c = testItem1.Id, copado__Job_Type__c = '_Generic_Test_', copado__Status__c = 'Not Started');
            copado__Result__c qGResult = new copado__Result__c(copado__Job_Type__c = '_Generic_Test_', copado__Status__c = 'Not Started');
            List<copado__Result__c> pmdTestResults = new List<copado__Result__c>{testResult, qGResult};
            insert pmdTestResults;
            copado__JobTemplate__c template = new copado__JobTemplate__c(Name = 'Run _Generic_Test_', copado__Version__c = 1);
            insert template;
            copado__JobExecution__c execution1 = new copado__JobExecution__c(
                copado__Template__c = template.Id,
                copado__DataJson__c = '{"resultIds" : [ "'+ testResult.Id +'" ]}'
            );
            copado__JobExecution__c execution2 = new copado__JobExecution__c(
                copado__Template__c = template.Id,
                copado__DataJson__c = '{"resultId" : "'+ qGResult.Id +'"}'
            );
            List<copado__JobExecution__c> executions = new List<copado__JobExecution__c>{execution1, execution2};
            insert executions;
            copado__JobStep__c jobStep1 = new copado__JobStep__c(Name = 'Evaluate _Generic_Test_ Result', copado__JobExecution__c = execution1.Id, copado__Type__c = 'Function');
            copado__JobStep__c jobStep2 = new copado__JobStep__c(Name = 'Evaluate _Generic_Test_ Result', copado__JobExecution__c = execution2.Id, copado__Type__c = 'Function');
            List<copado__JobStep__c> jobSteps = new List<copado__JobStep__c>{jobStep1, jobStep2};
            insert jobSteps;
            copado__Result__c jobStepResult1 = new copado__Result__c(copado__Job_Type__c = GENERIC_TOOL_NAME, copado__JobStep__c = jobStep1.Id, copado__Status__c = 'Success');
            copado__Result__c jobStepResult2 = new copado__Result__c(copado__Job_Type__c = GENERIC_TOOL_NAME_QG, copado__JobStep__c = jobStep2.Id, copado__Status__c = 'Success');
            List<copado__Result__c> results = new List<copado__Result__c>{jobStepResult1, jobStepResult2};
            insert results;
        }
    }
}