@isTest
public class EvaluateCodeScanResultTest {
    @isTest
    private static void executeSingleTest() {
        System.runAs([SELECT Id FROM User WHERE Username = 'username@myemail.com'][0]) {
            // Setup
            copado__Result__c jobStepResult = [SELECT Id FROM copado__Result__c WHERE copado__Job_Type__c = 'CodeScan Non-QG' LIMIT 1];

            // Exercise 
            new EvaluateCodeScanResult().execute(null, jobStepResult, 'Success');
            
            // Verify
            copado__Result__c testResult = [SELECT Id, copado__Status__c, copado__Progress_Status__c, copado__Error_Message__c FROM copado__Result__c WHERE copado__Job_Type__c = 'CodeScan' AND copado__Test__c != null LIMIT 1];
            System.assertEquals('Success', testResult.copado__Status__c, 'The test result should not be Failed');
            System.assertEquals('Success', testResult.copado__Progress_Status__c, 'The progress status should not be Failed');
        }
    }
    @isTest
    private static void executeSingleTestFailure() {
        System.runAs([SELECT Id FROM User WHERE Username = 'username@myemail.com'][0]) {
            // Setup
            copado__Result__c jobStepResult = [SELECT Id FROM copado__Result__c WHERE copado__Job_Type__c = 'CodeScan Non-QG' LIMIT 1];

            // Exercise 
            new EvaluateCodeScanResult().execute(null, jobStepResult, 'Failed');
            
            // Verify
            copado__Result__c testResult = [SELECT Id, copado__Status__c, copado__Progress_Status__c, copado__Error_Message__c FROM copado__Result__c WHERE copado__Job_Type__c = 'CodeScan' AND copado__Test__c != null LIMIT 1];
            System.assertEquals('Failed', testResult.copado__Status__c, 'The test result should be Failed');
            System.assertEquals('Failed', testResult.copado__Progress_Status__c, 'The progress status should be Failed');
        }
    }

    @isTest
    private static void executeQg() {
        System.runAs([SELECT Id FROM User WHERE Username = 'username@myemail.com'][0]) {
            // Setup
            copado__Result__c jobStepResult = [SELECT Id FROM copado__Result__c WHERE copado__Job_Type__c = 'CodeScan QG' LIMIT 1];
            
            // Exercise 
            new EvaluateCodeScanResult().execute(null, jobStepResult, 'Success');

            // Verify
            copado__Result__c testResult = [SELECT Id, copado__Status__c, copado__Progress_Status__c, copado__Error_Message__c FROM copado__Result__c WHERE copado__Job_Type__c = 'CodeScan' AND copado__Test__c = null LIMIT 1];
            System.assertEquals('Success', testResult.copado__Status__c, 'The test result should not be Failed');
            System.assertEquals('Success', testResult.copado__Progress_Status__c, 'The progress status should not be Failed');
        }
    }
    
    @isTest
    private static void executeQgFailure() {
        System.runAs([SELECT Id FROM User WHERE Username = 'username@myemail.com'][0]) {
            // Setup
            copado__Result__c jobStepResult = [SELECT Id FROM copado__Result__c WHERE copado__Job_Type__c = 'CodeScan QG' LIMIT 1];
            
            // Exercise 
            new EvaluateCodeScanResult().execute(null, jobStepResult, 'Failed');

            // Verify
            copado__Result__c testResult = [SELECT Id, copado__Status__c, copado__Progress_Status__c, copado__Error_Message__c FROM copado__Result__c WHERE copado__Job_Type__c = 'CodeScan' AND copado__Test__c = null LIMIT 1];
            System.assertEquals('Failed', testResult.copado__Status__c, 'The test result should be Failed');
            System.assertEquals('Failed', testResult.copado__Progress_Status__c, 'The progress status should be Failed');
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
                new EvaluateCodeScanResult().execute(null, null, 'Success');
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
            ProfileId = UserInfo.getProfileId(),
            LanguageLocaleKey = 'en_US'
        );
        insert runAsUser;
        
        System.runAs(runAsUser) {
            copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
            copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();
            userLicense.isCCMEnabled = true;
            userLicense.isCopadoEnabled = true;
            userLicense.userId = runAsUser.Id;
            copadoGlobalAPI.upsertCopadoLicense(userLicense);
            
            PermissionSetAssignment copado = new PermissionSetAssignment();
            copado.PermissionSetId = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Copado_User' LIMIT 1].Id;
            copado.AssigneeId = runAsUser.Id;
    
            insert copado;

        
            copado__ExtensionConfiguration__c extensionConfiguration = new copado__ExtensionConfiguration__c(copado__Active__c = true, copado__ExtensionTool__c = 'Manual Tests', copado__ExtensionApplication__c = 'Test');
            insert extensionConfiguration;

            copado__Test__c testItem1 = new copado__Test__c(Name = 'CodeScan Test - Single Execution', copado__ExtensionConfiguration__c = extensionConfiguration.Id, copado__ReadyToRun__c = true);
            copado__Test__c testItem2 = new copado__Test__c(Name = 'CodeScan Test - QG Execution', copado__ExtensionConfiguration__c = extensionConfiguration.Id, copado__ReadyToRun__c = true);
            List<copado__Test__c> tests = new List<copado__Test__c>{testItem1, testItem2};
            insert tests;

            copado__Result__c testResult = new copado__Result__c(copado__Test__c = testItem1.Id, copado__Job_Type__c = 'CodeScan', copado__Status__c = 'Not Started');
            copado__Result__c qGResult = new copado__Result__c(copado__Job_Type__c = 'CodeScan', copado__Status__c = 'Not Started');
            List<copado__Result__c> pmdTestResults = new List<copado__Result__c>{testResult, qGResult};
            insert pmdTestResults;

            copado__JobTemplate__c template = new copado__JobTemplate__c(Name = 'Run CodeScan', copado__Version__c = 1);
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

            copado__JobStep__c jobStep1 = new copado__JobStep__c(Name = 'Evaluate CodeScan Result', copado__JobExecution__c = execution1.Id, copado__Type__c = 'Function');
            copado__JobStep__c jobStep2 = new copado__JobStep__c(Name = 'Evaluate CodeScan Result', copado__JobExecution__c = execution2.Id, copado__Type__c = 'Function');
            List<copado__JobStep__c> jobSteps = new List<copado__JobStep__c>{jobStep1, jobStep2};
            insert jobSteps;

            copado__Result__c jobStepResult1 = new copado__Result__c(copado__Job_Type__c = 'CodeScan Non-QG', copado__JobStep__c = jobStep1.Id, copado__Status__c = 'Success');
            copado__Result__c jobStepResult2 = new copado__Result__c(copado__Job_Type__c = 'CodeScan QG', copado__JobStep__c = jobStep2.Id, copado__Status__c = 'Success');
            List<copado__Result__c> results = new List<copado__Result__c>{jobStepResult1, jobStepResult2};
            insert results;
        }
    }
}